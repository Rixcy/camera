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

    @Published private(set) var status: Status = .starting
    @Published private(set) var cameras: [CameraInfo] = []
    @Published private(set) var current: CameraInfo?
    @Published private(set) var lastPhoto: URL?
    /// Bumped on every shutter press so the view can flash.
    @Published private(set) var shutterCount = 0
    @Published private(set) var photoError: String?

    let engine = CaptureEngine()
    private var started = false
    private var observers: [NSObjectProtocol] = []

    private static let rememberedCameraKey = "selectedCameraID"
    private var rememberedCameraID: String? {
        get { UserDefaults.standard.string(forKey: Self.rememberedCameraKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.rememberedCameraKey) }
    }


    /// Asks for camera access if needed, then opens the preferred camera.
    func start() {
        guard !started else { return }
        started = true
        observeDevicesAndApp()

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

    func select(_ camera: CameraInfo) {
        guard camera != current || status != .running else { return }
        rememberedCameraID = camera.id
        current = camera
        engine.use(camera) { error in
            Task { @MainActor in
                guard self.current == camera else { return }
                self.status = error.map { .failed($0.localizedDescription) } ?? .running
            }
        }
    }

    func selectNext() {
        guard let next = CameraList.next(after: current?.id, in: cameras) else { return }
        select(next)
    }

    func takePhoto() {
        guard status == .running else { return }
        shutterCount += 1
        photoError = nil
        engine.capturePhoto(mirrored: current?.isMirrored ?? true) { result in
            let saved = result.flatMap(Self.save)
            Task { @MainActor in
                switch saved {
                case .success(let url): self.lastPhoto = url
                case .failure(let error): self.photoError = error.localizedDescription
                }
            }
        }
    }

    func revealLastPhoto() {
        guard let lastPhoto else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastPhoto])
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Photos go to ~/Pictures/Camera.
    nonisolated static var photosDirectory: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Camera", isDirectory: true)
    }

    nonisolated private static func save(_ data: Data) -> Result<URL, Error> {
        Result {
            let directory = photosDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = PhotoNaming.uniqueURL(in: directory, for: Date())
            try data.write(to: url, options: .withoutOverwriting)
            return url
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

    /// Keeps the list current as cameras are plugged in or unplugged, and
    /// turns the camera off while the app is hidden.
    private func observeDevicesAndApp() {
        let center = NotificationCenter.default
        let onDevicesChanged: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in self.devicesChanged() }
        }
        observers = [
            center.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main, using: onDevicesChanged),
            center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main, using: onDevicesChanged),
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
        if let current, cameras.contains(current) { return }
        // The live camera went away (or there was none): fall back.
        guard let camera = CameraList.preferred(in: cameras, remembered: rememberedCameraID) else {
            current = nil
            status = .noCamera
            return
        }
        // Don't overwrite the remembered camera: if it comes back, prefer it again.
        let remembered = rememberedCameraID
        select(camera)
        rememberedCameraID = remembered
    }
}
