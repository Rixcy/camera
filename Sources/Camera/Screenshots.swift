#if DEBUG
import AppKit
import CameraCore

/// Takes the README screenshots when a debug build runs with
/// `CAMERA_SCREENSHOTS=<directory>` (`make screenshots`), then quits. The
/// window shows a drawn orc (`ScreenshotScene`) on made-up cameras, so the
/// camera stays off and nothing from the real feed or photo library ends up
/// in the pictures.
@MainActor
enum Screenshots {
    static let directory = ProcessInfo.processInfo.environment["CAMERA_SCREENSHOTS"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

    static func take(of camera: CameraController, into directory: URL) {
        let cameras = [
            CameraInfo(id: "built-in", name: "MacBook Pro Camera", kind: .builtIn),
            CameraInfo(id: "external", name: "Studio Display Camera", kind: .external),
        ]
        let closeUp = ScreenshotScene.closeUp()
        let photo = CameraController.Photo(url: directory, thumbnail: closeUp)
        camera.stage(feed: closeUp, cameras: cameras, current: cameras[0], lastPhoto: photo)
        NSApp.activate()

        Task {
            do {
                try await Task.sleep(for: .seconds(1))
                try capture(directory.appendingPathComponent("camera.png"))
                // The display camera sees the same orc from further back, and
                // switching to it shows its name in a banner.
                camera.stage(feed: ScreenshotScene.wide(), cameras: cameras, current: cameras[1], lastPhoto: photo)
                try await Task.sleep(for: .seconds(0.5))
                try capture(directory.appendingPathComponent("switching.png"))
                NSApp.terminate(nil)
            } catch {
                FileHandle.standardError.write(Data("screenshots: \(error)\n".utf8))
                exit(1)
            }
        }
    }

    private static func capture(_ file: URL) throws {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else {
            throw ScreenshotError("no window to capture")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-l", String(window.windowNumber), file.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ScreenshotError("screencapture exited with \(process.terminationStatus)")
        }
    }
}

private struct ScreenshotError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
#endif
