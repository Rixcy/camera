import AVFoundation
import SwiftUI

/// Live camera feed, filling its bounds, flipped left-to-right when
/// `mirrored` is set.
struct PreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    let mirrored: Bool

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(previewLayer: previewLayer)
    }

    func updateNSView(_ view: PreviewNSView, context: Context) {
        view.mirrored = mirrored
    }
}

final class PreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    var mirrored = false {
        didSet { needsLayout = true }
    }

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = .black
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The title bar is hidden, so let the whole feed drag the window.
    override var mouseDownCanMoveWindow: Bool { true }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // With a transform set, place the layer by bounds and position, not frame.
        previewLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        previewLayer.setAffineTransform(mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
        CATransaction.commit()
    }
}
