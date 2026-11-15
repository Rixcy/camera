#if DEBUG
import AppKit
import CameraCore

/// Takes the README screenshots when a debug build runs with
/// `CAMERA_SCREENSHOTS=<directory>` (`make screenshots`), then quits. The
/// window shows a drawn scene and made-up cameras, so the camera stays off
/// and nothing from the real feed or photo library ends up in the pictures.
@MainActor
enum Screenshots {
    static let directory = ProcessInfo.processInfo.environment["CAMERA_SCREENSHOTS"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

    static func take(of camera: CameraController, into directory: URL) {
        let cameras = [
            CameraInfo(id: "built-in", name: "MacBook Pro Camera", kind: .builtIn),
            CameraInfo(id: "external", name: "Studio Display Camera", kind: .external),
        ]
        let feed = scene()
        let photo = CameraController.Photo(url: directory, thumbnail: feed)
        camera.stage(feed: feed, cameras: cameras, current: cameras[0], lastPhoto: photo)
        NSApp.activate()

        Task {
            do {
                try await Task.sleep(for: .seconds(1))
                try capture(directory.appendingPathComponent("camera.png"))
                // Switching cameras shows the new camera's name in a banner.
                camera.stage(feed: feed, cameras: cameras, current: cameras[1], lastPhoto: photo)
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

    /// Hills at dusk, standing in for the camera feed.
    private static func scene() -> NSImage {
        NSImage(size: NSSize(width: 1440, height: 960), flipped: false) { rect in
            NSGradient(colors: [
                NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.48, alpha: 1),
                NSColor(calibratedRed: 0.86, green: 0.50, blue: 0.52, alpha: 1),
                NSColor(calibratedRed: 0.30, green: 0.32, blue: 0.55, alpha: 1),
            ])!.draw(in: rect, angle: 90)

            NSColor(calibratedRed: 1, green: 0.93, blue: 0.78, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 900, y: 360, width: 150, height: 150)).fill()

            let hills: [(height: CGFloat, phase: CGFloat, color: NSColor)] = [
                (420, 0.0, NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.45, alpha: 1)),
                (320, 1.7, NSColor(calibratedRed: 0.27, green: 0.20, blue: 0.34, alpha: 1)),
                (200, 3.1, NSColor(calibratedRed: 0.14, green: 0.11, blue: 0.20, alpha: 1)),
            ]
            for hill in hills {
                let path = NSBezierPath()
                path.move(to: .zero)
                for x in stride(from: CGFloat(0), through: rect.width, by: 8) {
                    let wave = sin(x / 260 + hill.phase) * 50 + sin(x / 110 + hill.phase * 2) * 18
                    path.line(to: NSPoint(x: x, y: hill.height + wave))
                }
                path.line(to: NSPoint(x: rect.width, y: 0))
                path.close()
                hill.color.setFill()
                path.fill()
            }
            return true
        }
    }
}

private struct ScreenshotError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
#endif
