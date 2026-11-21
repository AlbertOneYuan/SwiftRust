// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import Combine

@available(iOS 17.0, *)
final class NativeHostingController: UIHostingController<NativeShellView> {
    private weak var model: NativeShellModel?
    private var subscription: AnyCancellable?
    init(model: NativeShellModel) {
        self.model = model
        super.init(rootView: NativeShellView(model: model))
        view.backgroundColor = .clear
        subscription = model.$remoteID.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setNeedsStatusBarAppearanceUpdate()
                self?.setNeedsUpdateOfHomeIndicatorAutoHidden()
                self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            }
        }
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) { nil }
    override var prefersStatusBarHidden: Bool { model?.remoteID != nil }
    override var prefersHomeIndicatorAutoHidden: Bool { model?.remoteID != nil }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { model?.remoteID != nil ? .all : [] }
}

@available(iOS 17.0, *)
struct NativeImmersiveSessionView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @AppStorage("native.show-connection-stats") private var showStatistics = false

    var body: some View {
        ZStack {
            NativeRemoteCanvas(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(NativeL("远程桌面画布"))
                .accessibilityIdentifier("native.remoteCanvas")
            if !model.connected && !model.confirmDisconnect && model.prompt == nil && model.errorMessage == nil && model.sheet == nil {
                VStack(spacing: 18) {
                    if model.connectionFailure == nil { ProgressView().tint(.white) }
                    Text(NativeL(model.status)).font(.subheadline).multilineTextAlignment(.center)
                    if model.connectionFailure?.hasRetry == true {
                        Button { model.resumeConnection("reconnect") } label: {
                            Text(NativeL("重新连接")).font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                                .background(nativeRustBlue, in: RoundedRectangle(cornerRadius: 12))
                        }.accessibilityIdentifier("native.reconnect")
                    }
                    Button(role: .destructive) {
                        if model.connectionFailure != nil { model.closeSession() } else { model.requestDisconnect() }
                    } label: {
                        Text(NativeL("取消连接")).font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityIdentifier("native.cancelConnection")
                }
                .padding(24).frame(maxWidth: 320).foregroundStyle(.white).buttonStyle(.plain)
            }
            if showStatistics && model.connected {
                GeometryReader { geometry in
                    let windowInsets = model.window?.safeAreaInsets ?? .zero
                    NativeConnectionStatistics(model: model)
                        .padding(.leading, max(geometry.safeAreaInsets.leading, windowInsets.left) + 16)
                        .padding(.top, max(geometry.safeAreaInsets.top, windowInsets.top) + 12)
                }.allowsHitTesting(false)
            }
            if model.showOSPassword { NativeOSPasswordSettings(model: model) }
            else if model.showResolutionAdjustment { NativeResolutionAdjustmentPopup(model: model) }
            else if model.showInputAdjustment { NativeInputAdjustmentPopup(model: model) }
        }
        .ignoresSafeArea()
        .background(Color.clear)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

@available(iOS 17.0, *)
private struct NativeConnectionStatistics: View {
    @ObservedObject var model: NativeShellModel
    @ObservedObject private var metrics: NativeConnectionMetrics
    init(model: NativeShellModel) { self.model = model; metrics = model.connectionMetrics }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(verbatim: "FPS \(metrics.values["fps"] ?? "—")")
                    .accessibilityLabel("Decoded FPS")
                    .accessibilityValue("\(metrics.values["fps"] ?? "—") FPS")
                Spacer(minLength: 8)
                Text(verbatim: "Delay \(metrics.values["delay"] ?? "—") ms")
                    .accessibilityLabel("Round-trip delay")
                    .accessibilityValue("\(metrics.values["delay"] ?? "—") ms")
            }.font(.caption.weight(.semibold))
            row("Speed", value: metrics.receiveRate ?? "—")
            row("Codec", value: metrics.values["codec_format"] ?? "—")
            row("Chroma", value: metrics.values["chroma"] ?? "—")
            row("Target bitrate", value: metrics.values["target_bitrate"].map { "\($0) kbps" } ?? "—")
            if model.remoteKind == .desktop, let desktop = model.currentResolution {
                row("Desktop", value: desktop.title)
            }
            row("Video", value: metrics.frameResolution?.title ?? "—")
        }
        .font(.caption2).monospacedDigit().lineLimit(1)
        .padding(12).frame(width: 200)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain).accessibilityIdentifier("native.connectionStatistics")
    }
    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(verbatim: title).foregroundStyle(.white.opacity(0.65))
            Spacer(minLength: 8)
            Text(verbatim: value)
        }
    }
}

@available(iOS 17.0, *)
enum NativeSessionContent {
    static func cameraFrame(in geometry: GeometryProxy, window: UIWindow?) -> CGRect {
        let size = geometry.size
        if #available(iOS 27.1, *) {
            var best: CGRect?
            let regions = geometry.reservedRegions(kind: .occlusion, options: .includeInactive)
            for region in regions {
                let margins = region.margins
                let insets = UIEdgeInsets(top: margins.top, left: margins.leading, bottom: margins.bottom, right: margins.trailing)
                let frame: CGRect = region.frame.inset(by: insets)
                guard frame.width > 8, frame.height > 8, frame.width < 240, frame.height < 240 else { continue }
                guard frame.minY < 64 || frame.minX < 64 || frame.maxX > size.width - 64 else { continue }
                if let current = best {
                    if frame.width * frame.height < current.width * current.height { best = frame }
                } else { best = frame }
            }
            if let frame = best { return boundedRing(around: frame, size: size) }

        }
        let safeArea = window?.safeAreaInsets ?? .zero
        let frame: CGRect
        if size.width > size.height {
            let cameraX = safeArea.right > safeArea.left ? size.width - max(62, safeArea.right) : max(24, safeArea.left - 38)
            frame = CGRect(x: cameraX, y: (size.height - 126) / 2, width: 38, height: 126)
        } else {
            frame = CGRect(x: (size.width - 126) / 2, y: max(24, safeArea.top - 38), width: 126, height: 38)
        }
        return boundedRing(around: frame, size: size)
    }

    private static func boundedRing(around camera: CGRect, size: CGSize) -> CGRect {
        let ring = camera.insetBy(dx: -20, dy: -20)
        return CGRect(x: min(max(ring.minX, 1), max(1, size.width - ring.width - 1)),
                      y: min(max(ring.minY, 1), max(1, size.height - ring.height - 1)),
                      width: ring.width, height: ring.height)
    }
}


@available(iOS 17.0, *)
struct NativeFloatingDock: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    let availableWidth: CGFloat
    var keyboardShown = false
    @State private var dragX = CGFloat.zero
    var body: some View {
        let travel = max(0, availableWidth - 110)
        let x = min(max(CGFloat(model.dockPosition) * travel + dragX, 0), travel)
        controls
            .padding(.top, 6)
            .contentShape(Rectangle())
            .background(NativeDockPan { translation, ended in
                if ended {
                    let end = min(max(CGFloat(model.dockPosition) * travel + translation, 0), travel)
                    let snapped = end < 32 ? 0 : end > travel - 32 ? travel : end
                    model.dockPosition = travel > 0 ? Double(snapped / travel) : 0
                    dragX = 0
                } else { dragX = translation }
            })
            .offset(x: x)
            .accessibilityElement(children: .contain).accessibilityIdentifier("native.floatingControls")
            .task(id: model.connected) { if model.connected { await model.send("sessionSettings", showError: false) } }
    }
    private var controls: some View {
        HStack(spacing: 0) {
            Button {
                model.remoteKeyboardVisible = false
                model.canvas?.toggleSystemKeyboard()
            } label: { Image(systemName: keyboardShown ? "keyboard.chevron.compact.down" : "keyboard").frame(width: 36, height: 34) }
                .accessibilityLabel(keyboardShown ? NativeL("收起系统键盘") : NativeL("系统键盘")).accessibilityIdentifier("native.keyboard")
                .disabled(model.remoteKind == .camera || model.sessionToggle("view-only"))
            Divider().frame(height: 18).overlay(.white.opacity(0.25))
            Button {
                model.canvas?.showShortcutKeyboard()
            } label: { Image(systemName: "command").frame(width: 36, height: 34) }
                .accessibilityLabel(NativeL("快捷键盘")).accessibilityIdentifier("native.shortcutsKeyboard")
                .disabled(model.remoteKind == .camera || model.sessionToggle("view-only"))
            Divider().frame(height: 18).overlay(.white.opacity(0.25))
            Menu { NativeSessionMenuContents(model: model) } label: { Image(systemName: "ellipsis").frame(width: 36, height: 34) }
                .menuOrder(.fixed)
                .simultaneousGesture(TapGesture().onEnded { model.canvas?.releaseInput() })
                .accessibilityLabel(NativeL("会话设置")).accessibilityIdentifier("native.sessionSettings")
        }
        .frame(width: 110, height: 34)
        .font(.system(size: 17, weight: .regular)).buttonStyle(.plain)
        .foregroundStyle(.white).tint(.white)
        .background {
            RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial).opacity(0.72)
        }
        .environment(\.colorScheme, .dark)
    }
}

@available(iOS 17.0, *)
final class NativeDockArea: UIView {
    var model: NativeShellModel
    private let host: UIHostingController<NativeDockBar>
    init(model: NativeShellModel) {
        self.model = model
        host = UIHostingController(rootView: NativeDockBar(model: model))
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        host.safeAreaRegions = []
        host.overrideUserInterfaceStyle = .dark
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)
        keyboardLayoutGuide.followsUndockedKeyboard = true
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.heightAnchor.constraint(equalToConstant: 40),
            host.view.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { nil }
    func updateControls() {
        host.view.isHidden = model.remoteKeyboardVisible
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let frame = keyboardLayoutGuide.layoutFrame
        let lift = frame.height > safeAreaInsets.bottom + 1 ? max(0, bounds.maxY - frame.minY) : 0
        model.canvas?.setKeyboardLift(lift)
        if host.rootView.keyboardShown != (lift > 0) {
            host.rootView = NativeDockBar(model: model, keyboardShown: lift > 0)
        }
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }
        let travel = max(0, bounds.width - 110)
        let bar = CGRect(x: CGFloat(model.dockPosition) * travel, y: host.view.frame.minY, width: 110, height: 40)
        if !model.remoteKeyboardVisible && bar.contains(point) { return super.hitTest(point, with: event) }
        return nil
    }
}

@available(iOS 17.0, *)
private struct NativeDockBar: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    var keyboardShown = false
    var body: some View {
        GeometryReader { geometry in
            NativeFloatingDock(model: model, availableWidth: geometry.size.width, keyboardShown: keyboardShown)
        }.frame(height: 40)
    }
}

// Observe only touches starting within the bar. A recognized pan cancels the
// underlying button tap, while a stationary touch remains a normal Menu tap.
@available(iOS 17.0, *)
private struct NativeDockPan: UIViewRepresentable {
    var moved: (CGFloat, Bool) -> Void
    func makeUIView(context: Context) -> PanArea { PanArea(moved: moved) }
    func updateUIView(_ view: PanArea, context: Context) { view.moved = moved }
    static func dismantleUIView(_ view: PanArea, coordinator: ()) { view.detach() }
    final class PanArea: UIView, UIGestureRecognizerDelegate {
        var moved: (CGFloat, Bool) -> Void
        private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(dragged))
        init(moved: @escaping (CGFloat, Bool) -> Void) {
            self.moved = moved
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
        }
        required init?(coder: NSCoder) { nil }
        func detach() { pan.view?.removeGestureRecognizer(pan) }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            pan.view?.removeGestureRecognizer(pan)
            window?.addGestureRecognizer(pan)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            bounds.contains(touch.location(in: self)) && !isHidden
        }
        @objc private func dragged() {
            switch pan.state {
            case .began, .changed: moved(pan.translation(in: window).x, false)
            case .ended: moved(pan.translation(in: window).x, true)
            case .cancelled, .failed: moved(0, true)
            default: break
            }
        }
    }
}
