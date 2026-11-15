@preconcurrency import AVFoundation
import CameraCore

/// Owns the AVCaptureSession. Every session call runs on `queue`, which is
/// why this type is `@unchecked Sendable`: AVFoundation objects are only
/// touched from that one serial queue.
final class CaptureEngine: @unchecked Sendable {
    enum EngineError: LocalizedError {
        case cameraUnavailable(String)
        case notReady
        case noPhotoData

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable(let name): "Couldn't open \(name)."
            case .notReady: "The camera isn't ready yet."
            case .noPhotoData: "The camera didn't return a photo."
            }
        }
    }

    let session = AVCaptureSession()
    /// Shows the raw feed. Mirroring is a layer transform applied by the
    /// view, so the connection is pinned unmirrored to avoid a double flip.
    let previewLayer: AVCaptureVideoPreviewLayer
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "Camera.CaptureEngine")
    private var input: AVCaptureDeviceInput?
    /// False while the app is hidden, so a camera switch or a fallback after
    /// an unplug doesn't turn the camera back on behind the user's back.
    private var wantsRunning = true
    private var pendingCaptures: [Int64: PhotoCaptureDelegate] = [:]

    private static let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera, .continuityCamera, .external, .deskViewCamera,
    ]

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        previewLayer.videoGravity = .resizeAspectFill
        queue.async { [self] in
            session.beginConfiguration()
            // .photo gives full-resolution stills; .high caps them at the video size.
            session.sessionPreset = session.canSetSessionPreset(.photo) ? .photo : .high
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()
        }
    }

    /// Safe to call from any thread.
    static func availableCameras() -> [CameraInfo] {
        AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
            .devices
            .filter { $0.isConnected && !$0.isSuspended }
            .map { CameraInfo(id: $0.uniqueID, name: $0.localizedName, kind: kind(of: $0)) }
    }

    private static func kind(of device: AVCaptureDevice) -> CameraInfo.Kind {
        switch device.deviceType {
        case .builtInWideAngleCamera: .builtIn
        case .continuityCamera: .continuity
        case .deskViewCamera: .deskView
        default: .external
        }
    }

    /// On failure the session is left with no camera and stopped, so the
    /// error screen never sits over a camera whose light is still on.
    func use(_ camera: CameraInfo, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [self] in
            do {
                try attach(camera)
                if wantsRunning, !session.isRunning { session.startRunning() }
                completion(nil)
            } catch {
                detach()
                completion(error)
            }
        }
    }

    private func attach(_ camera: CameraInfo) throws {
        let unavailable = EngineError.cameraUnavailable(camera.name)
        guard let device = AVCaptureDevice(uniqueID: camera.id),
              let newInput = try? AVCaptureDeviceInput(device: device)
        else { throw unavailable }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let input { session.removeInput(input) }
        input = nil
        guard session.canAddInput(newInput) else { throw unavailable }
        session.addInput(newInput)
        input = newInput

        // macOS connects the preview layer to a new input by itself, even one
        // made with sessionWithNoConnection; add a connection only if it didn't.
        func feedsPreview(from input: AVCaptureInput) -> Bool {
            previewLayer.connection?.inputPorts.contains { $0.input === input } == true
        }
        if !feedsPreview(from: newInput),
           let port = newInput.ports.first(where: { $0.mediaType == .video }) {
            let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
            if session.canAddConnection(connection) { session.addConnection(connection) }
        }
        // Without a preview connection the window would stay black.
        guard feedsPreview(from: newInput), let preview = previewLayer.connection else { throw unavailable }

        for connection in [preview, photoOutput.connection(with: .video)].compactMap({ $0 })
        where connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    private func detach() {
        session.beginConfiguration()
        if let input { session.removeInput(input) }
        input = nil
        session.commitConfiguration()
        if session.isRunning { session.stopRunning() }
    }

    func start() {
        queue.async { [self] in
            wantsRunning = true
            if input != nil, !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            wantsRunning = false
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Blocks so the camera light is off by the time the app exits.
    func stopAndWait() {
        queue.sync {
            wantsRunning = false
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Hands back JPEG bytes, tagged to display mirrored when `mirrored` is
    /// set so the photo matches the preview.
    func capturePhoto(mirrored: Bool, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        queue.async { [self] in
            // capturePhoto raises an uncatchable exception without a live
            // video connection, e.g. right after the camera is unplugged.
            guard session.isRunning,
                  let connection = photoOutput.connection(with: .video),
                  connection.isActive, connection.isEnabled,
                  photoOutput.availablePhotoCodecTypes.contains(.jpeg)
            else {
                completion(.failure(EngineError.notReady))
                return
            }
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            let id = settings.uniqueID
            let delegate = PhotoCaptureDelegate { [self] result in
                queue.async { self.pendingCaptures[id] = nil }
                completion(result.map { data in
                    // A photo that can't be re-tagged is still worth keeping.
                    mirrored ? PhotoMirroring.mirrored(data) ?? data : data
                })
            }
            // AVFoundation holds its delegate weakly.
            pendingCaptures[id] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void
    private var result: Result<Data, Error>?

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(CaptureEngine.EngineError.noPhotoData)
        }
    }

    /// Always the last callback, even when processing never ran (for
    /// example the session stopped mid-capture), so cleanup lives here.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        completion(result ?? .failure(error ?? CaptureEngine.EngineError.noPhotoData))
    }
}
