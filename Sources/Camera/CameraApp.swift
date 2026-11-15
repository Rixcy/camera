import AppKit
import CameraCore
import SwiftUI

@main
struct CameraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var camera = CameraController()

    var body: some Scene {
        Window("Camera", id: "camera") {
            ContentView()
                .environmentObject(camera)
                .onAppear { appDelegate.engine = camera.engine }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 480)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CameraCommands(camera: camera)
        }
    }
}

private struct CameraCommands: Commands {
    @ObservedObject var camera: CameraController

    var body: some Commands {
        CommandMenu("Camera") {
            Button("Take Photo") { camera.takePhoto() }
                .disabled(camera.status != .running)
            Button("Switch Camera") { camera.selectNext() }
                .disabled(camera.cameras.count < 2)
            Divider()
            ForEach(Array(camera.cameras.enumerated()), id: \.element.id) { index, info in
                let item = Toggle(info.name, isOn: Binding(
                    get: { camera.current == info },
                    set: { _ in camera.select(info) }
                ))
                if index < 9 {
                    item.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                } else {
                    item
                }
            }
            Divider()
            Button("Show Photos in Finder") {
                let directory = CameraController.photosDirectory
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                NSWorkspace.shared.open(directory)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set once the window appears so the camera can be stopped on quit.
    var engine: CaptureEngine?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stopAndWait()
    }
}
