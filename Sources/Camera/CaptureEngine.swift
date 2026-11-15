@preconcurrency import AVFoundation
import CameraCore

/// Owns the AVCaptureSession. Every session call runs on `queue`, which is
/// why this type is `@unchecked Sendable`: AVFoundation objects are only
/// touched from that one serial queue.
final class CaptureEngine: @unchecked Sendable {
    enum EngineError: LocalizedError {
        case cameraUnavailable(String)
        case noPhotoData

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable(let name): "Couldn't open \(name)."
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
    private var pendingCaptures: [Int64: PhotoCaptureDelegate] = [:]

    private static let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera, .continuityCamera, .external, .deskViewCamera,
    ]

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        previewLayer.videoGravity = .resizeAspectFill
        queue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .high
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()
        }
    }

    /// Cameras currently connected. Safe to call from any thread.
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

    /// Swaps the session's input to `camera` and starts the session.
    func use(_ camera: CameraInfo, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [self] in
            guard let device = AVCaptureDevice(uniqueID: camera.id),
                  let newInput = try? AVCaptureDeviceInput(device: device)
            else {
                completion(EngineError.cameraUnavailable(camera.name))
                return
            }
            session.beginConfiguration()
            if let input { session.removeInput(input) }
            guard session.canAddInput(newInput) else {
                if let input { session.addInput(input) }
                session.commitConfiguration()
                completion(EngineError.cameraUnavailable(camera.name))
                return
            }
            session.addInput(newInput)
            input = newInput
            // Removing the old input dropped its preview connection; wire the new one.
            if let port = newInput.ports.first(where: { $0.mediaType == .video }) {
                let preview = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
                if session.canAddConnection(preview) { session.addConnection(preview) }
            }
            for connection in [previewLayer.connection, photoOutput.connection(with: .video)] {
                guard let connection, connection.isVideoMirroringSupported else { continue }
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
            completion(nil)
        }
    }

    func start() {
        queue.async { [self] in
            if input != nil, !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Stops the camera before returning, so the green light is off by the
    /// time the app exits.
    func stopAndWait() {
        queue.sync {
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Captures a JPEG and hands back its encoded bytes, tagged to display
    /// mirrored when `mirrored` is set so it matches the preview.
    func capturePhoto(mirrored: Bool, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        queue.async { [self] in
            guard session.isRunning, photoOutput.connection(with: .video) != nil else {
                completion(.failure(EngineError.noPhotoData))
                return
            }
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            let id = settings.uniqueID
            // The delegate is retained here until AVFoundation reports back.
            let delegate = PhotoCaptureDelegate { [self] result in
                queue.async { self.pendingCaptures[id] = nil }
                completion(result.flatMap { data in
                    guard mirrored else { return .success(data) }
                    return PhotoMirroring.mirrored(data).map(Result.success) ?? .failure(EngineError.noPhotoData)
                })
            }
            pendingCaptures[id] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(CaptureEngine.EngineError.noPhotoData))
        }
    }
}
