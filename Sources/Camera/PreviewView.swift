import AVFoundation
import SwiftUI

/// Live camera feed, filling its bounds. Mirroring is applied by the
/// caller with a horizontal flip so it never depends on connection timing.
struct PreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(session: session)
    }

    func updateNSView(_ view: PreviewNSView, context: Context) {}
}

final class PreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init(frame: .zero)
        wantsLayer = true
        layer = previewLayer
    }

    /// The title bar is hidden, so let the whole feed drag the window.
    override var mouseDownCanMoveWindow: Bool { true }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
