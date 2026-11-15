import AppKit
@preconcurrency import AVFoundation
import CameraCore

/// The window's model: which camera is live, which cameras exist, and the
/// last photo taken. Capture work is forwarded to `CaptureEngine`. One
/// instance lives for the whole app, so its callbacks capture it strongly.
@MainActor
final class CameraController: ObservableObject {
    enum Status: Equatable {
        case starting
        case running
        case denied
        case noCamera
        case failed(String)
    }

    struct Photo {
        let url: URL
        let thumbnail: NSImage?
    }

    @Published private(set) var status: Status = .starting
    @Published private(set) var cameras: [CameraInfo] = []
    /// The camera the session last switched to (or failed to). It only
    /// changes once the engine has finished, so the preview's mirroring and
    /// the feed it shows always belong to the same camera.
    @Published private(set) var current: CameraInfo?
    @Published private(set) var lastPhoto: Photo?
    /// Bumped on every shutter press so the view can flash.
    @Published private(set) var shutterCount = 0
    @Published private(set) var photoError: String?
    /// Shown instead of the live feed when set. Only screenshots set it.
    @Published private(set) var standInFeed: NSImage?

    let engine = CaptureEngine()
    private var started = false
    /// The camera the engine is switching to, if a switch is in flight.
    private var requested: CameraInfo?
    /// Holding Space would otherwise save a photo per key repeat.
    private var isCapturing = false
    private var observers: [NSObjectProtocol] = []

    private static let rememberedCameraKey = "selectedCameraID"
    private var rememberedCameraID: String? {
        get { UserDefaults.standard.string(forKey: Self.rememberedCameraKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.rememberedCameraKey) }
    }

    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        if let directory = Screenshots.directory {
            Screenshots.take(of: self, into: directory)
            return
        }
        #endif
        observeNotifications()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            openPreferredCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.openPreferredCamera() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    /// `remember` is false for automatic fallbacks, so the user's chosen
    /// camera is preferred again once it is reconnected.
    func select(_ camera: CameraInfo, remember: Bool = true) {
        if camera == requested { return }
        if camera == current, status == .running, requested == nil { return }
        requested = camera
        engine.use(camera) { error in
            Task { @MainActor in
                guard self.requested == camera else { return }
                self.requested = nil
                self.current = camera
                if let error {
                    self.status = .failed(error.localizedDescription)
                } else {
                    self.status = .running
                    if remember { self.rememberedCameraID = camera.id }
                }
            }
        }
    }

    func selectNext() {
        guard let next = CameraList.next(after: (requested ?? current)?.id, in: cameras) else { return }
        select(next)
    }

    func retry() {
        guard let camera = current else { return }
        select(camera)
    }

    func takePhoto() {
        guard status == .running, !isCapturing else { return }
        isCapturing = true
        shutterCount += 1
        photoError = nil
        engine.capturePhoto(mirrored: current?.isMirrored ?? true) { result in
            let saved = result.flatMap(Self.save)
            Task { @MainActor in
                self.isCapturing = false
                switch saved {
                case .success(let photo):
                    self.lastPhoto = Photo(
                        url: photo.url,
                        thumbnail: photo.thumbnail.map { NSImage(cgImage: $0, size: .zero) }
                    )
                case .failure(let error):
                    self.photoError = error.localizedDescription
                }
            }
        }
    }

    func revealLastPhoto() {
        guard let lastPhoto else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastPhoto.url])
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated static var photosDirectory: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Camera", isDirectory: true)
    }

    /// Runs on the capture queue, keeping file I/O and decoding off the main thread.
    nonisolated private static func save(_ data: Data) -> Result<(url: URL, thumbnail: CGImage?), Error> {
        Result {
            let directory = photosDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = PhotoNaming.uniqueURL(in: directory, for: Date())
            try data.write(to: url, options: .withoutOverwriting)
            return (url, PhotoThumbnail.make(from: data))
        }
    }

    private func openPreferredCamera() {
        refreshCameras()
        guard let camera = CameraList.preferred(in: cameras, remembered: rememberedCameraID) else {
            status = .noCamera
            return
        }
        select(camera)
    }

    private func refreshCameras() {
        cameras = CameraList.sorted(CaptureEngine.availableCameras())
    }

    private func observeNotifications() {
        let center = NotificationCenter.default
        let onDevicesChanged: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in self.devicesChanged() }
        }
        observers = [
            center.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main, using: onDevicesChanged),
            center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main, using: onDevicesChanged),
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: engine.session, queue: .main) { note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
                let message = error?.localizedDescription ?? "The camera stopped unexpectedly."
                Task { @MainActor in self.status = .failed(message) }
            },
            center.addObserver(forName: NSApplication.didHideNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in self.engine.stop() }
            },
            center.addObserver(forName: NSApplication.didUnhideNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in self.engine.start() }
            },
        ]
    }

    private func devicesChanged() {
        guard status != .denied else { return }
        refreshCameras()
        if let active = requested ?? current, cameras.contains(active) { return }
        guard let camera = CameraList.preferred(in: cameras, remembered: rememberedCameraID) else {
            requested = nil
            current = nil
            status = .noCamera
            return
        }
        select(camera, remember: false)
    }
}

#if DEBUG
extension CameraController {
    /// Shows `current` as live on a still image, without touching the camera.
    func stage(feed: NSImage, cameras: [CameraInfo], current: CameraInfo, lastPhoto: Photo?) {
        standInFeed = feed
        self.cameras = cameras
        self.current = current
        self.lastPhoto = lastPhoto
        status = .running
    }
}
#endif
