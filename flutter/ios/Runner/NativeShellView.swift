// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import VisionKit
import AVFoundation

let nativeRemoteIDFont = Font.system(.title2, design: .rounded, weight: .medium).monospacedDigit()
let nativeRustBlue = Color(red: 0, green: 113.0 / 255, blue: 1)

@available(iOS 17.0, *)
struct NativeShellView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @AppStorage("native-show-home-login") private var showHomeLogin = true
    @State private var search = ""
    @State private var settingsPath: [NativeSettingsRoute] = []
    @State private var aboutRequest = 0
    @AppStorage("native-appearance") private var appearance = "system"

    private var scheme: ColorScheme? {
        appearance == "dark" ? .dark : appearance == "light" ? .light : nil
    }

    var body: some View {
        Group {
            if model.remoteID != nil && !model.fileBrowserMinimized {
                if model.remoteKind == .terminal { NativeTerminalScreen(model: model) }
                else if model.remoteKind == .files { NativeFileScreen(model: model) }
                else { NativeImmersiveSessionView(model: model) }
            } else {
                homeNavigation
            }
        }
        .environment(\.locale, Locale(identifier: NativeTranslationStore.appleIdentifier(localization.language)))
        .environment(\.layoutDirection, ["ar", "he", "ur", "fa"].contains(localization.language) ? .rightToLeft : .leftToRight)
        .nativeAutomaticTranslation()
        .tint(nativeRustBlue)
        .preferredColorScheme(scheme)
        .statusBarHidden(model.remoteID != nil && !model.fileBrowserMinimized)
        .persistentSystemOverlays(model.remoteID != nil && !model.fileBrowserMinimized ? .hidden : .automatic)
        .sheet(item: Binding(get: { model.sheet == .scanner ? nil : model.sheet }, set: { if model.sheet != .scanner { model.sheet = $0 } })) { sheet in
            NavigationStack {
                switch sheet {
                case .scanner: EmptyView()
                case .quickDeviceSettings: NativeQuickDeviceSettings(model: model).toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { model.sheet = nil } } }
                case .downloads: NativeDownloadsView(files: model.fileBrowser).toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { model.sheet = nil } } }
                case .sessionSettings: NativeSessionSettingsView(model: model)
                case .osPassword: NativeOSPasswordSettings(model: model)
                case .account: NativeAccountView(model: model)
                case .gestures: NativeGestureHelp(mode: model.inputMode)
                case .servers: NativeServerSettings(model: model)
                case .connectionPrompt:
                    if let prompt = model.prompt { NativeConnectionPrompt(model: model, prompt: prompt).id(prompt.id) }
                case .resolution: NativeResolutionSettings(model: model)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { model.sheet = nil } } }
                case .scroll: NativeScrollSettings()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { model.sheet = nil } } }
                case .pointer: NativePointerSettings(model: model)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { model.sheet = nil } } }
                }
            }.modifier(NativeDisconnectConfirmation(model: model))
        }
        .fullScreenCover(isPresented: Binding(get: { model.sheet == .scanner }, set: { if !$0 && model.sheet == .scanner { model.sheet = nil } })) {
            NativeQRConnectionView(model: model).modifier(NativeDisconnectConfirmation(model: model))
        }
        .modifier(NativeDisconnectConfirmation(model: model, active: model.sheet == nil))
        .task { await model.refresh() }
    }

    private var selection: Binding<NativeSection> {
        Binding(get: { model.selected ?? .connection }, set: { model.selected = $0 })
    }

    private var homeNavigation: some View {
        TabView(selection: selection) {
            ForEach(NativeSection.allCases) { section in
                homePage(section)
                    .tabItem {
                        Label { Text(NativeL(section.title)) } icon: {
                            Image(uiImage: NativeTabSymbols.image(section.symbol))
                        }
                    }
                    .tag(section)
            }
        }
        .environment(\.symbolVariants, .none)
        .toolbar(model.selected == .settings && !settingsPath.isEmpty ? .hidden : .visible, for: .tabBar)
    }

    private func homePage(_ section: NativeSection) -> some View {
        NavigationStack(path: section == .settings ? $settingsPath : .constant([])) {
            Group {
                if section == .settings {
                    NativeSettingsView(model: model, appearance: $appearance, aboutRequest: aboutRequest)
                } else {
                    NativeConnectionView(model: model, favoritesOnly: section == .favorites,
                        search: section == .favorites ? $search : .constant(""), showLogin: showHomeLogin) { support in
                            settingsPath = support ? [.support] : []
                            if !support { aboutRequest += 1 }
                            model.selected = .settings
                        }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(section == .connection ? "SwiftRust" : NativeL(section.title))
            .navigationBarTitleDisplayMode(section == .connection ? .large : .inline)
            .toolbar(section == .favorites ? .hidden : .visible, for: .navigationBar)
        }
    }

}

private enum NativeTabSymbols {
    private static let images: [String: UIImage] = Dictionary(uniqueKeysWithValues: ["house", "star", "gearshape"].map { name in
        let configuration = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let symbol = UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(.black, renderingMode: .alwaysOriginal)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30)).image { _ in
            if let symbol {
                let scale = min(28 / symbol.size.width, 28 / symbol.size.height)
                let size = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
                symbol.draw(in: CGRect(x: (30-size.width)/2, y: (30-size.height)/2, width: size.width, height: size.height))
            }
        }
        return (name, image.withRenderingMode(.alwaysTemplate))
    })
    static func image(_ name: String) -> UIImage { images[name] ?? UIImage() }
}

@available(iOS 17.0, *)
struct NativeInputIcon: View {
    @ObservedObject private var localization = NativeLocalization.shared
    let mode: String
    var body: some View {
        if mode == "trackpad" {
            Image(systemName: "rectangle.and.hand.point.up.left")
        } else {
            Image(systemName: mode.hasPrefix("touch") ? "hand.point.up.left" : "computermouse")
        }
    }
}

@available(iOS 17.0, *)
private struct NativeConnectionView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    let favoritesOnly: Bool
    @Binding var search: String
    let showLogin: Bool
    let openProject: (Bool) -> Void
    @FocusState private var idFocused: Bool

    private var visiblePeers: [NativePeer] {
        model.peers.filter { peer in
            (!favoritesOnly || peer.favorite) &&
            (search.isEmpty || peer.name.localizedCaseInsensitiveContains(search) || peer.id.contains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if model.fileBrowserMinimized {
                    HStack {
                        Button(NativeL("下载管理")) { model.sheet = .downloads }
                        Spacer()
                        Button(NativeL("返回文件传输")) { model.fileBrowserMinimized = false }
                    }.padding().background(.background, in: RoundedRectangle(cornerRadius: 16))
                }
                if favoritesOnly {
                    NativeDeviceSearch(text: $search).frame(height: 52)
                        .accessibilityIdentifier("native.deviceSearch")
                }
                VStack(alignment: .leading, spacing: 22) {
                if !favoritesOnly {
                    connectionCard
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(favoritesOnly ? NativeL("收藏的设备") : NativeL("最近连接")).font(.title3.bold())
                        Spacer()
                        if !visiblePeers.isEmpty { Text("\(visiblePeers.count)").font(.subheadline).foregroundStyle(.secondary) }
                    }
                    if visiblePeers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: favoritesOnly ? "star" : "desktopcomputer")
                                .font(.system(size: 36, weight: .regular)).foregroundStyle(.secondary)
                            Text(search.isEmpty ? (favoritesOnly ? NativeL("还没有收藏的设备") : NativeL("你的设备，从这里连接")) : NativeL("没有匹配的设备"))
                                .font(.headline)
                            Text(search.isEmpty ? NativeL("输入远端 ID，开始第一次连接。") : NativeL("试试其他设备名称或 ID。"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 44)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(visiblePeers) { peer in
                                NativePeerRow(model: model, peer: peer)
                            }
                        }
                    }
                }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 12).padding(.top, 20).padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(NativeHomeRefresh { await model.refresh() })
        }
        .toolbar {
            if !favoritesOnly {
                ToolbarItem(placement: .topBarTrailing) { projectMenu }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var projectMenu: some View {
        Menu {
            #if SWIFTRUST_APPSTORE
            Button { openProject(true) } label: { Label(NativeL("支持 SwiftRust"), systemImage: "heart.fill") }
                .accessibilityIdentifier("native.homeSupport")
            #endif
            Link(destination: NativeContact.feedback) { Label(NativeL("发送反馈"), systemImage: "envelope") }
            if let reviewURL = NativeContact.review {
                Link(destination: reviewURL) { Label(NativeL("去 App Store 评价"), systemImage: "star") }
            } else {
                Button {} label: { Label(NativeL("去 App Store 评价"), systemImage: "star") }.disabled(true)
            }
            Divider()
            Button { openProject(false) } label: { Label(NativeL("关于项目"), systemImage: "info.circle") }
                .accessibilityIdentifier("native.homeAbout")
        } label: {
            Image(systemName: "info.circle").foregroundStyle(nativeRustBlue)
        }
        .accessibilityLabel(NativeL("项目信息"))
        .accessibilityIdentifier("native.projectMenu")
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(NativeL("远程连接")).font(.headline)
                Spacer()
                if showLogin {
                    Button { model.sheet = .account } label: {
                        Image(systemName: "person.crop.circle").font(.system(size: 23, weight: .regular))
                            .frame(width: 44, height: 32).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(nativeRustBlue)
                        .accessibilityLabel(model.accountName.isEmpty ? NativeL("登录") : model.accountName)
                        .accessibilityIdentifier("native.homeLogin")
                }
                Button { model.sheet = .scanner } label: {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 23, weight: .regular))
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(nativeRustBlue)
                    .accessibilityLabel(NativeL("二维码连接")).accessibilityIdentifier("native.scanQR")
            }
            TextField(NativeL("远程 ID"), text: $model.idText, prompt: Text(NativeL("远程 ID")).foregroundColor(Color(uiColor: .secondaryLabel)))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.asciiCapable).font(nativeRemoteIDFont)
                .foregroundStyle(nativeRustBlue)
                .padding(16).background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .focused($idFocused).submitLabel(.go)
                .onSubmit { idFocused = false; Task { await model.connect() } }
                .accessibilityIdentifier("native.remoteID")
            Button { idFocused = false; Task { await model.connect() } } label: {
                HStack {
                    if model.isConnecting { ProgressView().tint(.white) }
                    Text(model.isConnecting ? NativeL("正在连接…") : NativeL("连接")).font(.headline).foregroundColor(.white)
                    Image(systemName: "arrow.right").fontWeight(.semibold).foregroundColor(.white)
                }.frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .buttonStyle(NativeConnectStyle())
            .disabled(!model.ready || model.idText.trimmingCharacters(in: .whitespaces).isEmpty || model.isConnecting)
            .accessibilityIdentifier("native.connect")
            if !model.ready {
                HStack { ProgressView(); Text(NativeL("正在准备连接服务…")).foregroundStyle(.secondary) }.font(.footnote)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("native.connectionCard")
    }
}

@available(iOS 17.0, *)
private struct NativeConnectStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(nativeRustBlue, in: RoundedRectangle(cornerRadius: 12))
            .opacity(!isEnabled ? 0.38 : configuration.isPressed ? 0.5 : 1)
    }
}

@available(iOS 17.0, *)
private struct NativeDeviceSearch: UIViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeUIView(context: Context) -> UISearchBar {
        let view = UISearchBar()
        view.searchBarStyle = .minimal
        view.placeholder = "搜索设备名称或 ID"
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.enablesReturnKeyAutomatically = false
        view.tintColor = .label
        let symbols = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        view.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: symbols)?.withTintColor(.label, renderingMode: .alwaysTemplate), for: .search, state: .normal)
        view.setImage(UIImage(systemName: "xmark.circle", withConfiguration: symbols)?.withTintColor(.label, renderingMode: .alwaysTemplate), for: .clear, state: .normal)
        view.searchTextField.attributedPlaceholder = NSAttributedString(string: "搜索设备名称或 ID", attributes: [.foregroundColor: UIColor.secondaryLabel])
        view.searchTextField.textColor = .label
        view.searchTextField.leftView?.tintColor = .label
        view.delegate = context.coordinator
        return view
    }
    func updateUIView(_ view: UISearchBar, context: Context) {
        context.coordinator.text = $text
        view.keyboardAppearance = context.environment.colorScheme == .dark ? .dark : .light
        if view.text != text { view.text = text }
    }
    final class Coordinator: NSObject, UISearchBarDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { text.wrappedValue = searchText }
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    }
}

@available(iOS 17.0, *)
struct NativeQRConnectionView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @State private var cameraReady = false
    @State private var scannedID: String?
    @State private var message: String?

    static func remoteID(from payload: String) -> String? {
        let value = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) { return value }
        guard let url = URLComponents(string: value), url.scheme?.lowercased() == "rustdesk" else { return nil }
        let id = url.queryItems?.first(where: { $0.name == "id" })?.value ?? url.host ?? ""
        guard !id.isEmpty, id.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return id
    }

    static func scanRect(in size: CGSize) -> CGRect {
        let side = max(0, min(360, min(size.width, size.height) * 0.66))
        return CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let region = Self.scanRect(in: geometry.size)
                ZStack {
                    Color.black
                    if let scannedID {
                        VStack(spacing: 24) {
                            Image(systemName: "checkmark.circle").font(.system(size: 42)).foregroundStyle(.green)
                            Text(NativeL("远程 ID")).font(.headline)
                            Text(scannedID).font(nativeRemoteIDFont).foregroundStyle(nativeRustBlue)
                            Button(NativeL("连接")) {
                                model.idText = scannedID; model.sheet = nil
                                Task { await model.connect(to: scannedID) }
                            }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                            Button(NativeL("重新扫描")) { self.scannedID = nil; message = nil }.buttonStyle(.bordered).controlSize(.large)
                        }
                        .padding(28).frame(maxWidth: 360)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                        .padding(24)
                    } else if cameraReady {
                        NativeQRScanner(region: region) { payload in
                            if let id = Self.remoteID(from: payload) { scannedID = id; message = nil }
                            else { message = NativeL("请扫描包含远程 ID 的 SwiftRust 连接二维码") }
                        } failure: { message = $0; cameraReady = false }
                        Path { path in
                            path.addRect(CGRect(origin: .zero, size: geometry.size))
                            path.addRoundedRect(in: region, cornerSize: CGSize(width: 24, height: 24))
                        }.fill(.black.opacity(0.5), style: FillStyle(eoFill: true)).allowsHitTesting(false)
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                            .frame(width: region.width, height: region.height)
                            .position(x: region.midX, y: region.midY).allowsHitTesting(false)
                        Text(NativeL("将二维码放入框内"))
                            .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                            .position(x: region.midX, y: region.maxY + 30).allowsHitTesting(false)
                    } else {
                        ContentUnavailableView(NativeL("二维码连接"), systemImage: "qrcode.viewfinder", description: Text(message ?? NativeL("正在准备摄像头…")))
                    }

                }.foregroundStyle(.white)
            }
            .ignoresSafeArea()
            VStack {
                HStack {
                    Text(NativeL("二维码连接")).font(.title3.weight(.semibold))
                    Spacer()
                    Button { model.sheet = nil } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }.accessibilityLabel(NativeL("取消"))
                }
                Spacer()
                if cameraReady, let message {
                    Text(message).font(.subheadline).padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }.foregroundStyle(.white).preferredColorScheme(.dark).statusBarHidden()
        .task {
            guard DataScannerViewController.isSupported else { message = NativeL("此设备不支持相机扫码，请手动输入远程 ID"); return }
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            cameraReady = allowed && DataScannerViewController.isAvailable
            if !cameraReady { message = NativeL("请在系统设置中允许 SwiftRust 使用摄像头") }
        }
    }
}

@available(iOS 17.0, *)
private struct NativeQRScanner: UIViewControllerRepresentable {
    let region: CGRect
    let receive: (String) -> Void
    let failure: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(receive: receive, failure: failure) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
            recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true,
            isGuidanceEnabled: false, isHighlightingEnabled: false)
        scanner.delegate = context.coordinator
        scanner.regionOfInterest = region
        Task { @MainActor in
            do { try scanner.startScanning() }
            catch { failure(error.localizedDescription) }
        }
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) { scanner.regionOfInterest = region }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { scanner.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let receive: (String) -> Void
        let failure: (String) -> Void
        init(receive: @escaping (String) -> Void, failure: @escaping (String) -> Void) { self.receive = receive; self.failure = failure }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue { receive(payload); return }
            }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            failure(error.localizedDescription)
        }
    }
}

@available(iOS 17.0, *)
private struct NativeDisconnectConfirmation: ViewModifier {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    var active = true
    func body(content: Content) -> some View {
        let notice = model.prompt.flatMap { !$0.password && !$0.twoFactor ? $0 : nil }
        let disconnecting = model.confirmDisconnect
        let error = model.errorMessage
        content.alert(disconnecting ? NativeL("断开连接？") : error != nil ? NativeL("无法完成操作") : NativeL(notice?.title ?? "连接提示"), isPresented: Binding(
            get: { active && (model.confirmDisconnect || error != nil || notice != nil) },
            set: {
                if !$0 {
                    if disconnecting { model.confirmDisconnect = false }
                    else if error != nil { model.errorMessage = nil }
                    else { model.prompt = nil }
                }
            }
        )) {
            if disconnecting {
                Button(NativeL("取消"), role: .cancel) { model.confirmDisconnect = false }
                Button(NativeL("断开连接"), role: .destructive) { model.closeSession() }
            } else if error != nil {
                Button(NativeL("好"), role: .cancel) { model.errorMessage = nil }
            } else if let notice {
                if notice.insecure {
                    Button(NativeL("继续")) { model.continuePrompt(notice, skip: false) }.keyboardShortcut(.defaultAction)
                    Button(NativeL("不再提示并继续")) { model.continuePrompt(notice, skip: true) }
                } else if notice.hasRetry {
                    Button(NativeL("重新连接")) { model.resumeConnection("reconnect") }.keyboardShortcut(.defaultAction)
                } else if !notice.connectionError {
                    Button(NativeL("好")) { model.prompt = nil }
                }
                Button(NativeL("取消连接"), role: .destructive) { model.closeSession() }
            }
        } message: {
            Text(disconnecting ? (model.remoteKind == .terminal ? NativeL("将结束当前连接中的所有终端标签。") : model.remoteKind == .files ? NativeL("当前文件传输也会停止。") : NativeL("是否结束当前远程连接？")) : NativeL(error ?? notice?.text ?? ""))
        }
    }
}

// Own refresh completion explicitly; SwiftUI's refreshable can retain its spinner
// when this navigation-bar-free page is replaced by a remote session.
@available(iOS 17.0, *)
private struct NativeHomeRefresh: UIViewRepresentable {
    let action: @MainActor () async -> Void
    func makeUIView(context: Context) -> RefreshAnchor {
        RefreshAnchor(action: action)
    }
    func updateUIView(_ view: RefreshAnchor, context: Context) { view.action = action }
    static func dismantleUIView(_ view: RefreshAnchor, coordinator: ()) { view.detach() }

    final class RefreshAnchor: UIView {
        var action: @MainActor () async -> Void
        private weak var scroll: UIScrollView?
        private let control = UIRefreshControl()
        private var task: Task<Void, Never>?
        init(action: @escaping @MainActor () async -> Void) {
            self.action = action
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            control.addTarget(self, action: #selector(refresh), for: .valueChanged)
        }
        required init?(coder: NSCoder) { nil }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { detach() }
            else { attach() }
        }
        override func layoutSubviews() { super.layoutSubviews(); if scroll == nil { attach() } }
        private func attach() {
            var parent = superview
            while let view = parent {
                if let target = view as? UIScrollView {
                    if scroll !== target {
                        detach()
                        scroll = target
                        target.refreshControl = control
                        target.alwaysBounceVertical = true
                    }
                    return
                }
                parent = view.superview
            }
        }
        @objc private func refresh() {
            guard task == nil else { return }
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                defer { control.endRefreshing(); task = nil }
                await action()
            }
        }
        func detach() {
            task?.cancel(); task = nil
            control.endRefreshing()
            if scroll?.refreshControl === control { scroll?.refreshControl = nil }
            scroll = nil
        }
    }
}
