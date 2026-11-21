// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import PhotosUI
import AppIntents
import UniformTypeIdentifiers

struct NativeLaunchLink: Equatable {
    let id: String
    var mode: NativeSessionKind = .desktop
    var relay = false
    var approval = false
    var connect = true
    var newWindow = false
    static func normalizedID(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.filter { !$0.isWhitespace }
        return !compact.isEmpty && compact.utf8.allSatisfy({ (48...57).contains($0) }) ? compact : trimmed
    }
    init(id: String, mode: NativeSessionKind = .desktop) { self.id = Self.normalizedID(id); self.mode = mode }
    init(url: URL) throws {
        guard url.scheme?.lowercased() == "swiftrust", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil,
              parts.host == "connect", parts.path.isEmpty || parts.path == "/" else { throw NativeCoreError(message: "无效的 SwiftRust 启动链接") }
        let items = parts.queryItems ?? []
        let allowed = Set(["id", "mode", "relay", "approval", "connect", "newWindow"])
        guard items.allSatisfy({ allowed.contains($0.name) }), Set(items.map(\.name)).count == items.count else { throw NativeCoreError(message: "启动链接含未知或重复参数") }
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        let id = Self.normalizedID(values["id"] ?? "")
        guard !id.isEmpty, id.count <= 512, !id.contains(where: { $0.isWhitespace || $0.isNewline || $0.asciiValue.map { $0 < 32 } == true }) else { throw NativeCoreError(message: "请输入有效的远程 ID 或地址") }
        guard let mode = NativeSessionKind(rawValue: values["mode"] ?? "desktop") else { throw NativeCoreError(message: "不支持的连接类型") }
        func flag(_ key: String, default fallback: Bool = false) throws -> Bool {
            guard let value = values[key] else { return fallback }
            switch value.lowercased() { case "1", "true": return true; case "0", "false": return false; default: throw NativeCoreError(message: "启动参数需要 true/false 或 1/0") }
        }
        self.id = id; self.mode = mode
        relay = try flag("relay"); approval = try flag("approval")
        connect = try flag("connect", default: true); newWindow = try flag("newWindow")
    }
    var url: URL {
        var parts = URLComponents(); parts.scheme = "swiftrust"; parts.host = "connect"
        parts.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "mode", value: mode.rawValue)]
        if relay { parts.queryItems?.append(URLQueryItem(name: "relay", value: "1")) }
        if approval { parts.queryItems?.append(URLQueryItem(name: "approval", value: "1")) }
        if !connect { parts.queryItems?.append(URLQueryItem(name: "connect", value: "0")) }
        if newWindow { parts.queryItems?.append(URLQueryItem(name: "newWindow", value: "1")) }
        return parts.url ?? URL(fileURLWithPath: "/")
    }
}

@available(iOS 17.0, *)
@MainActor enum NativeWindowLaunch {
    static let activityType = "me.airefactor.swiftrust.connection"
    static func connectFromIntent(_ link: NativeLaunchLink) async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive && $0.windows.contains(where: \.isKeyWindow) }
            ?? scenes.first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        guard let delegate = scene?.delegate as? SceneDelegate else { throw NativeCoreError(message: "连接窗口尚未准备好，请重试") }
        try await delegate.connectFromIntent(link)
    }
    static func open(_ link: NativeLaunchLink?, action: String? = nil, error: @escaping (String) -> Void) {
        guard UIApplication.shared.supportsMultipleScenes else { error(NativeL("当前系统不支持同时打开多个窗口")); return }
        let activity = NSUserActivity(activityType: activityType)
        if let link { activity.userInfo = ["url": link.url.absoluteString]; activity.title = link.id }
        if let action { activity.userInfo = ["quickAction": action] }
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { failure in
            Task { @MainActor in error(failure.localizedDescription) }
        }
    }
}

@available(iOS 17.0, *)
extension NativeShellModel {
    func openLaunchLink(_ link: NativeLaunchLink, inNewScene: Bool = false) async {
        if link.newWindow && !inNewScene {
            NativeWindowLaunch.open(link) { self.errorMessage = $0 }; return
        }
        guard remoteID == nil else { errorMessage = "当前窗口已有连接，请先断开或在新窗口中打开"; return }
        selected = .connection; sheet = nil
        idText = link.id; remoteKind = link.mode; forceRelay = link.relay
        if link.connect { await connect(to: link.id, kind: link.mode, approval: link.approval, relay: link.relay) }
    }
}

@available(iOS 17.0, *)
struct NativeURLSchemeHelp: View {
    var body: some View {
        List {
            Section(NativeL("启动链接")) {
                Text("swiftrust://connect?id=160111967&mode=desktop").font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Text(NativeL("链接会打开对应连接入口，并按正常流程验证。不会自动结束当前窗口中的连接。"))
            }
            Section(NativeL("参数")) {
                LabeledContent("id", value: NativeL("远程 ID、域名或 IP:端口（必填）"))
                LabeledContent("mode", value: "desktop / terminal / files / camera")
                LabeledContent("relay", value: NativeL("强制中继，默认 false"))
                LabeledContent("approval", value: NativeL("请求远端批准，默认 false"))
                LabeledContent("connect", value: NativeL("立即连接，默认 true；false 仅填入"))
                LabeledContent("newWindow", value: NativeL("在新窗口打开，默认 false；需要系统支持"))
                Text(NativeL("布尔参数支持 true/false 或 1/0。地址中的特殊字符请使用 URL 编码；IPv6 带端口时使用 [地址]:端口。链接不支持密码或 Auth key 参数。"))
            }
            Section(NativeL("终端与文件传输示例")) {
                Text("swiftrust://connect?id=mac.local&mode=terminal&newWindow=1").textSelection(.enabled)
                Text("swiftrust://connect?id=192.168.1.10%3A21118&mode=files").textSelection(.enabled)
            }
            Section(NativeL("多窗口")) {
                Text(UIApplication.shared.supportsMultipleScenes ? NativeL("当前系统支持多窗口。通过设备选项中的“在新窗口连接”打开其他机器，再使用系统分屏排列窗口。每个窗口独立管理连接。") : NativeL("当前系统未开放多窗口。启动链接和桌面快捷启动仍可使用；新窗口参数会提示不可用。"))
            }
            Section(NativeL("桌面快捷启动")) {
                Text(NativeL("在设备选项中选择“添加到主屏幕”，设置名称和图标，再通过系统界面添加设备快捷指令。也可在快捷指令中使用 SwiftRust 的“连接设备”原生动作，再添加到主屏幕。"))
                Link(NativeL("Apple：将快捷指令添加到主屏幕"), destination: URL(string: "https://support.apple.com/guide/shortcuts/apd735880972/ios")!)
            }
        }.navigationTitle(NativeL("URL Scheme")).navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
struct NativeDeviceLauncher: View {
    let peer: NativePeer
    @State private var mode = NativeSessionKind.desktop
    @State private var relay = false
    @State private var newWindow = false
    @State private var photo: PhotosPickerItem?
    @State private var customImage: UIImage?
    @State private var exportURL: URL?
    @State private var iconName = ""
    @State private var preparingShortcut = false
    @State private var shortcutImport: NativeShortcutFile?
    @State private var error: String?
    private var link: NativeLaunchLink {
        var value = NativeLaunchLink(id: peer.id, mode: mode); value.relay = relay; value.newWindow = newWindow; return value
    }
    var body: some View {
        Form {
            Section(NativeL("设备快捷启动")) {
                TextField(NativeL("桌面图标名称"), text: $iconName)
                    .accessibilityIdentifier("native.launcherName")
                Picker(NativeL("连接方式"), selection: $mode) {
                    Text(NativeL("远程控制")).tag(NativeSessionKind.desktop)
                    Text(NativeL("终端")).tag(NativeSessionKind.terminal)
                    Text(NativeL("传输文件")).tag(NativeSessionKind.files)
                    Text(NativeL("查看摄像头")).tag(NativeSessionKind.camera)
                }
                Toggle(NativeL("强制中继连接"), isOn: $relay).tint(.green)
                Toggle(NativeL("在新窗口打开"), isOn: $newWindow).tint(.green).disabled(!UIApplication.shared.supportsMultipleScenes)
                Text(link.url.absoluteString).font(.footnote.monospaced()).textSelection(.enabled)
                Button(NativeL("复制启动链接"), systemImage: "doc.on.doc") { UIPasteboard.general.url = link.url }
            }
            Section(NativeL("自定义桌面图标")) {
                HStack {
                    if let customImage { Image(uiImage: customImage).resizable().scaledToFit().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14)) }
                    else { NativePeerBadge(peer: peer) }
                    PhotosPicker(selection: $photo, matching: .images) { Text(NativeL("选择图标照片")) }
                }
                Button(NativeL("导出图标图片"), systemImage: "square.and.arrow.up") { exportIcon() }
                if let exportURL { ShareLink(item: exportURL) { Label(NativeL("保存或分享图标"), systemImage: "photo") } }
            }
            Section(NativeL("添加设备快捷指令")) {
                Button { prepareShortcut() } label: { Label(preparingShortcut ? NativeL("正在准备…") : NativeL("复制设备 ID 并导入模板"), systemImage: "square.and.arrow.down") }
                    .disabled(preparingShortcut)
                    .accessibilityIdentifier("native.addDeviceShortcut")
                Text(NativeL("点击后打开已签名的快捷指令文件。选择“快捷指令”，按导入问题粘贴远程 ID，再点“添加快捷指令”。若分享列表没有快捷指令，先存储到文件，再点该文件导入。导入后可添加到主屏幕并选择自定义图标。"))
                Text(NativeL("模板只包含 SwiftRust 的原生“连接设备”动作，不经过 Safari。连接类型、强制中继与新窗口已按当前选项选择模板，设备 ID 需在导入时确认。"))
                Link(NativeL("打开快捷指令"), destination: URL(string: "shortcuts://")!)
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }.navigationTitle(NativeL("添加到主屏幕")).navigationBarTitleDisplayMode(.inline)
            .onAppear { if iconName.isEmpty { iconName = peer.name } }
            .sheet(item: $shortcutImport) { NativeShortcutImportSheet(file: $0.url) }
            .task(id: photo) {
                do { if let data = try await photo?.loadTransferable(type: Data.self) { customImage = UIImage(data: data); exportURL = nil } }
                catch { self.error = error.localizedDescription }
            }
    }
    private func prepareShortcut() {
        preparingShortcut = true; error = nil
        defer { preparingShortcut = false }
        do {
            let file = try NativeShortcutTemplates.export(mode: mode, relay: relay, newWindow: newWindow, name: iconName.isEmpty ? peer.name : iconName)
            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: peer.id]],
                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(600)])
            shortcutImport = NativeShortcutFile(url: file)
        } catch { self.error = error.localizedDescription }
    }
    private func exportIcon() {
        let renderer = ImageRenderer(content: NativePeerBadge(peer: peer).scaleEffect(8).frame(width: 512, height: 512).background(Color(uiColor: .systemGroupedBackground)))
        guard let data = (customImage ?? renderer.uiImage)?.pngData() else { error = NativeL("无法生成图标"); return }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftRust-device-\(UUID().uuidString).png")
            try data.write(to: url, options: .atomic); exportURL = url; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct NativeShortcutFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct NativeShortcutTemplates {
    static func export(mode: NativeSessionKind, relay: Bool = false, newWindow: Bool = false, name: String) throws -> URL {
        guard let source = Bundle.main.url(forResource: "SwiftRust-\(mode.rawValue)-r\(relay ? 1 : 0)w\(newWindow ? 1 : 0)", withExtension: "shortcut", subdirectory: "ShortcutTemplates") else { throw NativeCoreError(message: "缺少已签名的快捷指令模板") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let clean = String(name.filter { !$0.isNewline && $0 != "/" && $0 != "\\" && !($0.asciiValue.map { $0 < 32 } ?? false) }.prefix(80)).trimmingCharacters(in: .whitespaces)
        let file = folder.appendingPathComponent((clean.isEmpty ? "SwiftRust" : clean) + ".shortcut")
        try FileManager.default.copyItem(at: source, to: file)
        return file
    }
}

@available(iOS 17.0, *)
private struct NativeShortcutImportSheet: UIViewControllerRepresentable {
    let file: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

enum NativeIntentMode: String, AppEnum {
    case desktop, terminal, files, camera
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "连接方式"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.desktop: "远程控制", .terminal: "终端", .files: "传输文件", .camera: "查看摄像头"]
}
struct NativeConnectDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "连接设备"
    static var description = IntentDescription("打开 SwiftRust 并连接指定设备。可添加到主屏幕并自定义图标。")
    @Parameter(title: "远程 ID 或地址") var id: String
    @Parameter(title: "连接方式", default: .desktop) var mode: NativeIntentMode
    @Parameter(title: "新窗口", default: false) var newWindow: Bool
    @Parameter(title: "强制中继", default: false) var relay: Bool
    static var parameterSummary: some ParameterSummary { Summary("连接 \(\.$id)（\(\.$mode)）") }
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        var link = NativeLaunchLink(id: id, mode: NativeSessionKind(rawValue: mode.rawValue) ?? .desktop)
        link.newWindow = newWindow; link.relay = relay
        _ = try NativeLaunchLink(url: link.url)
        try await NativeWindowLaunch.connectFromIntent(link)
        return .result()
    }
}
struct NativeDeviceAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NativeConnectDeviceIntent(), phrases: ["使用 \(.applicationName) 连接设备"], shortTitle: "连接设备", systemImageName: "display")
    }
}
