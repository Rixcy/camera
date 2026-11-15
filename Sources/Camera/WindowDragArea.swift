import AppKit
import SwiftUI

/// Drags the window from wherever the mouse goes down on it. The title bar
/// is hidden, and a SwiftUI window only moves from its title bar on its own.
class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    // Drag on the first click, even while another app is active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// Fills its bounds with black and drags the window from anywhere in them.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        let view = WindowDragNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .black
        return view
    }

    func updateNSView(_ view: WindowDragNSView, context: Context) {}
}
