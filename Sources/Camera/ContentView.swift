import CameraCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var camera: CameraController
    @FocusState private var focused: Bool
    @State private var flash = false
    @State private var cameraBanner: String?
    @State private var bannerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black

            switch camera.status {
            case .starting, .running:
                PreviewView(
                    previewLayer: camera.engine.previewLayer,
                    mirrored: camera.current?.isMirrored ?? true
                )
            case .denied:
                MessageView(
                    symbol: "video.slash",
                    title: "Camera access is off",
                    detail: "Allow Camera in System Settings › Privacy & Security › Camera, then reopen the app.",
                    action: ("Open Privacy Settings", camera.openPrivacySettings)
                )
            case .noCamera:
                MessageView(
                    symbol: "video.slash",
                    title: "No camera found",
                    detail: "Connect a camera and it will appear here.",
                    action: nil
                )
            case .failed(let message):
                MessageView(
                    symbol: "exclamationmark.triangle",
                    title: "Camera unavailable",
                    detail: message,
                    action: camera.current.map { current in ("Try Again", { camera.select(current) }) }
                )
            }

            Color.white
                .opacity(flash ? 0.85 : 0)
                .allowsHitTesting(false)

            VStack {
                if let cameraBanner {
                    Text(cameraBanner)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 36)
                        .transition(.opacity)
                }
                Spacer()
                ControlBar(refocus: { focused = true })
            }
        }
        .frame(minWidth: 360, minHeight: 240)
        .ignoresSafeArea()
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            focused = true
            camera.start()
        }
        .onKeyPress(keys: [.space, .return]) { _ in
            camera.takePhoto()
            return .handled
        }
        .onKeyPress(.tab) {
            camera.selectNext()
            return .handled
        }
        .onKeyPress(.escape) {
            NSApp.keyWindow?.performClose(nil)
            return .handled
        }
        .onChange(of: camera.shutterCount) {
            withAnimation(.easeOut(duration: 0.05)) {
                flash = true
            } completion: {
                withAnimation(.easeOut(duration: 0.3)) { flash = false }
            }
        }
        .onChange(of: camera.current) { old, new in
            // Announce switches, not the first camera opening.
            guard old != nil, let new else { return }
            showBanner(new.name)
        }
    }

    private func showBanner(_ text: String) {
        bannerTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { cameraBanner = text }
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) { cameraBanner = nil }
        }
    }
}

private struct ControlBar: View {
    @EnvironmentObject private var camera: CameraController
    let refocus: () -> Void

    var body: some View {
        // The side slots always take equal space, even when empty, so the
        // shutter stays centred.
        HStack {
            Color.clear
                .frame(height: 54)
                .overlay(alignment: .leading) { LastPhotoButton() }

            ShutterButton {
                camera.takePhoto()
                refocus()
            }
            .disabled(camera.status != .running)

            Color.clear
                .frame(height: 54)
                .overlay(alignment: .trailing) { CameraMenu(refocus: refocus) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }
}

private struct ShutterButton: View {
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white, lineWidth: 3).frame(width: 54, height: 54)
                Circle().fill(.white).frame(width: 44, height: 44)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help("Take Photo (Space)")
        .accessibilityLabel("Take Photo")
    }
}

private struct LastPhotoButton: View {
    @EnvironmentObject private var camera: CameraController

    var body: some View {
        if let error = camera.photoError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
        } else if let url = camera.lastPhoto, let image = NSImage(contentsOf: url) {
            Button(action: camera.revealLastPhoto) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle())
            .help("Show in Finder")
            .accessibilityLabel("Show last photo in Finder")
        }
    }
}

private struct CameraMenu: View {
    @EnvironmentObject private var camera: CameraController
    let refocus: () -> Void

    var body: some View {
        if camera.cameras.count > 1 {
            Menu {
                ForEach(camera.cameras) { info in
                    Toggle(info.name, isOn: Binding(
                        get: { camera.current == info },
                        set: { _ in camera.select(info); refocus() }
                    ))
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            } primaryAction: {
                camera.selectNext()
                refocus()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Switch Camera (Tab) — hold for list")
            .accessibilityLabel("Switch Camera")
        }
    }
}

private struct MessageView: View {
    let symbol: String
    let title: String
    let detail: String
    let action: (String, () -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
            Text(title).font(.title3.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if let action {
                Button(action.0, action: action.1)
                    .controlSize(.large)
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 60)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
