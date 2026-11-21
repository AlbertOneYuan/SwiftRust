// SwiftRust integration © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import SafariServices

struct NativeTailnetPeer: Decodable, Identifiable, Sendable {
    let DNSName: String?
    let HostName: String?
    let TailscaleIPs: [String]?
    let Online: Bool?
    var id: String { host.isEmpty ? (HostName ?? "unknown") : host }
    var name: String { HostName ?? DNSName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? id }
    var host: String { (DNSName?.isEmpty == false ? DNSName : nil)?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? TailscaleIPs?.first ?? "" }
}
struct NativeTailnetStatus: Decodable, Sendable {
    let BackendState: String
    let AuthURL: String?
    let TailscaleIPs: [String]?
    let Peer: [String: NativeTailnetPeer]?
}
private struct NativeTailnetProxy: Decodable, Sendable {
    let address: String
    let username: String
    let password: String
}

private actor NativeTailnetRuntime {
    private var node: Int32?
    private var proxy: NativeTailnetProxy?

    func start(directory: String, authKey: String? = nil) throws {
        guard node == nil else { return }
        let handle = tailscale_new()
        guard handle > 0 else { throw NativeCoreError(message: "无法创建 Tailscale 节点") }
        node = handle
        do {
            _ = try action("configure")
            try check(tailscale_set_dir(handle, directory))
            try check(tailscale_set_hostname(handle, "swiftrust-ios"))
            try check(tailscale_set_ephemeral(handle, 0))
            if let authKey { try check(tailscale_set_authkey(handle, authKey)) }
            try check(tailscale_start(handle))
            try rebind()
        } catch { _ = SwiftRustTSClose(handle); node = nil; throw error }
    }
    private func check(_ code: Int32) throws {
        guard code != 0 else { return }
        var buffer = [CChar](repeating: 0, count: 1024)
        if let node { _ = tailscale_errmsg(node, &buffer, buffer.count) }
        throw NativeCoreError(message: buffer[0] == 0 ? "Tailscale 操作失败" : String(cString: buffer))
    }
    private func action(_ method: String) throws -> Data {
        guard let node else { throw NativeCoreError(message: "Tailscale 尚未启动") }
        var pointer: UnsafeMutablePointer<CChar>?
        let code = SwiftRustTSAction(node, method, &pointer)
        guard let pointer else { throw NativeCoreError(message: "Tailscale 未返回结果") }
        defer { free(pointer) }
        let data = Data(String(cString: pointer).utf8)
        if code != 0 {
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
            throw NativeCoreError(message: error?["error"] ?? "Tailscale 操作失败")
        }
        return data
    }
    func login() throws { _ = try action("login") }
    func rebind() throws { proxy = try JSONDecoder().decode(NativeTailnetProxy.self, from: action("proxy")) }
    func status() throws -> NativeTailnetStatus {
        guard let node else { throw NativeCoreError(message: "Tailscale 尚未启动") }
        var pointer: UnsafeMutablePointer<CChar>?
        try check(tailscale_status_json(node, &pointer))
        guard let pointer else { throw NativeCoreError(message: "Tailscale 状态不可用") }
        defer { free(pointer) }
        return try JSONDecoder().decode(NativeTailnetStatus.self, from: Data(String(cString: pointer).utf8))
    }
    func route() -> NativeTailnetProxy? { proxy }
    func stop(logout: Bool) throws {
        guard let handle = node else { return }
        if logout { _ = try action("logout") }
        let result = SwiftRustTSClose(handle)
        node = nil; proxy = nil
        try check(result)
    }
}

@MainActor
final class NativeTailscaleController: ObservableObject {
    static let shared = NativeTailscaleController()
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "native.tailscale.enabled")
    @Published private(set) var busy = false
    @Published private(set) var state = "未启用"
    @Published private(set) var running = false
    @Published private(set) var ips: [String] = []
    @Published private(set) var peers: [NativeTailnetPeer] = []
    @Published var error: String?
    private let runtime = NativeTailnetRuntime()
    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SwiftRust-Tailscale", isDirectory: true)
    }
    func start(authKey: String? = nil) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            var folder = directory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            if authKey != nil {
                try await runtime.stop(logout: false)
                _ = try NativeRustCore.call("tailscaleRoute", ["address": ""])
            }
            try await runtime.start(directory: folder.path, authKey: authKey)
            enabled = true; UserDefaults.standard.set(true, forKey: "native.tailscale.enabled")
            try await update()
        } catch {
            self.error = authKey == nil ? error.localizedDescription : NativeL("Auth key 登录失败，请检查密钥是否有效。")
            state = "启动失败"
        }
    }
    func stop(logout: Bool = false) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await runtime.stop(logout: logout)
            _ = try NativeRustCore.call("tailscaleRoute", ["address": ""])
            if logout, FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
            enabled = false; UserDefaults.standard.set(false, forKey: "native.tailscale.enabled")
            state = "未启用"; running = false; ips = []; peers = []
        } catch { self.error = error.localizedDescription }
    }
    private func update() async throws {
        let status = try await runtime.status()
        running = status.BackendState == "Running"
        switch status.BackendState {
        case "Running": state = "已连接"
        case "NeedsLogin": state = "需要登录"
        case "NeedsMachineAuth": state = "等待管理员批准"
        case "Starting": state = "正在连接…"
        default: state = status.BackendState
        }
        ips = status.TailscaleIPs ?? []
        peers = Array((status.Peer ?? [:]).values).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if let proxy = await runtime.route() {
            let hosts = peers.flatMap { [$0.host, $0.name] }.filter { !$0.isEmpty }
            _ = try NativeRustCore.call("tailscaleRoute", ["address": proxy.address, "username": proxy.username, "password": proxy.password, "hosts": hosts])
        }
    }
    func refresh() async {
        guard enabled, !busy else { return }
        if state == "未启用" { await start(); return }
        do { try await update() } catch { self.error = error.localizedDescription }
    }
    func foreground() async {
        guard enabled else { return }
        if state == "未启用" || state == "启动失败" { await start(); return }
        do { try await runtime.rebind(); try await update() } catch { self.error = error.localizedDescription }
    }
    func login() async -> URL? {
        if !enabled { await start() }
        guard enabled, !busy else { return nil }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await runtime.login()
            for _ in 0..<30 {
                let status = try await runtime.status()
                if let value = status.AuthURL, let url = URL(string: value),
                   url.scheme == "https", url.host == "login.tailscale.com" { return url }
                try await Task.sleep(for: .milliseconds(300))
            }
            throw NativeCoreError(message: "授权地址尚未就绪，请稍后重试。")
        } catch { self.error = error.localizedDescription; return nil }
    }
    static func validAuthKey(_ key: String) -> Bool {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasPrefix("tskey-auth-") && value.count > "tskey-auth-".count
            && !value.contains(where: { $0.isWhitespace || $0.isNewline })
    }
    func login(authKey: String) async {
        guard !busy, !running else { return }
        guard Self.validAuthKey(authKey) else { error = NativeL("请输入有效的 Tailscale Auth key（tskey-auth-…）。"); return }
        await start(authKey: authKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    static func isTailnetTarget(_ address: String, peers: [NativeTailnetPeer] = []) -> Bool {
        var host = address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("["), let end = host.firstIndex(of: "]") { host = String(host[host.index(after: host.startIndex)..<end]) }
        else if let colon = host.firstIndex(of: ":"), host.lastIndex(of: ":") == colon { host = String(host[..<colon]) }
        host = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let chunks = host.split(separator: ".", omittingEmptySubsequences: false)
        let parts = chunks.compactMap { UInt8($0) }
        return (chunks.count == 4 && parts.count == 4 && parts[0] == 100 && (64..<128).contains(parts[1]))
            || host.hasPrefix("fd7a:115c:a1e0:") || host.hasSuffix(".ts.net")
            || peers.contains { $0.host.lowercased() == host || $0.name.lowercased() == host }
    }
    func prepareConnection(_ address: String) async throws {
        guard enabled, Self.isTailnetTarget(address, peers: peers) else { return }
        if state == "未启用" { await start() }
        try await update()
        guard running else { throw NativeCoreError(message: "请先在设置中完成 Tailscale 登录，并等待节点连接。") }
    }
}

private struct NativeTailscaleLogin: UIViewControllerRepresentable, Identifiable {
    let url: URL
    var id: String { url.absoluteString }
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

@available(iOS 17.0, *)
struct NativeTailscaleSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var controller: NativeTailscaleController
    @ObservedObject var model: NativeShellModel
    @State private var login: NativeTailscaleLogin?
    @State private var authKey = ""
    @AppStorage("native.tailscale.port") private var port = "21118"
    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { controller.enabled }, set: { enabled in Task { if enabled { await controller.start() } else { await controller.stop() } } })) {
                    Label(NativeL("启用内嵌 Tailscale"), systemImage: "point.3.connected.trianglepath.dotted")
                }.tint(.green).disabled(controller.busy).accessibilityIdentifier("native.tailscaleEnabled")
                LabeledContent(NativeL("节点状态"), value: NativeL(controller.state))
                if controller.busy { ProgressView(NativeL("正在处理…")) }
                ForEach(controller.ips, id: \.self) { Text($0).font(.footnote.monospaced()).textSelection(.enabled) }
            } footer: { Text(NativeL("仅在 SwiftRust 内生效，不创建系统 VPN，不接管其他 App 的网络。后台运行仍受 iOS 系统限制。")) }
            if !controller.running {
                Section {
                    SecureField("Auth key", text: $authKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("native.tailscaleAuthKey")
                    Button(NativeL("使用 Auth key 登录")) {
                        let submitted = authKey; authKey = ""
                        Task { await controller.login(authKey: submitted) }
                    }.disabled(controller.busy || model.remoteID != nil || !NativeTailscaleController.validAuthKey(authKey))
                        .accessibilityIdentifier("native.tailscaleAuthKeyLogin")
                } header: { Text(NativeL("密钥登录")) } footer: {
                    Text(NativeL("使用 Tailscale 管理后台生成的 Auth key，无需网页授权。密钥仅用于本次认证，不保存到设置；登录后的节点凭据由 Tailscale 管理。切换账号请先退出登录。"))
                }
            }
            if controller.enabled {
                Section {
                    if !controller.running {
                        Button(NativeL("登录 Tailscale")) { Task { if let url = await controller.login() { login = NativeTailscaleLogin(url: url) } } }
                            .disabled(controller.busy).accessibilityIdentifier("native.tailscaleLogin")
                    }
                    Button(NativeL("刷新状态")) { Task { await controller.refresh() } }.disabled(controller.busy)
                    Button(NativeL("退出登录"), role: .destructive) { Task { await controller.stop(logout: true) } }.disabled(controller.busy)
                }
            }
            if let error = controller.error { Section { Text(NativeL(error)).foregroundStyle(.red) } }
            Section {
                TextField(NativeL("直连端口"), text: $port).keyboardType(.numberPad)
            } header: { Text(NativeL("远程设备")) } footer: {
                Text(NativeL("远程设备需安装 Tailscale 和兼容的远程桌面服务，开启直接 IP 访问（默认端口 21118）。连接仍需远程访问密码与 Tailnet 访问权限。"))
            }
            if controller.peers.isEmpty {
                Section { Text(controller.enabled ? NativeL("登录并连接后，这里会显示有权访问的 Tailnet 设备。") : NativeL("启用后，使用你的 Tailscale 账号登录。")).foregroundStyle(.secondary) }
            } else {
                Section(NativeL("Tailnet 设备")) {
                    ForEach(controller.peers) { peer in
                        Button {
                            guard let port = UInt16(port), port > 0 else { controller.error = NativeL("请输入 1–65535 范围内的端口。"); return }
                            let host = peer.host.contains(":") ? "[\(peer.host)]" : peer.host
                            Task { await model.connect(to: "\(host):\(port)") }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(peer.name).foregroundStyle(.primary)
                                    Text(peer.TailscaleIPs?.first ?? peer.host).font(.footnote.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(peer.Online == true ? NativeL("在线") : NativeL("离线")).font(.caption).foregroundStyle(peer.Online == true ? Color.green : Color.secondary)
                            }
                        }.disabled(!controller.running || model.remoteID != nil || peer.host.isEmpty)
                    }
                }
            }
        }
        .navigationTitle("Tailscale").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $login) { $0 }
        .onDisappear { authKey = "" }
        .onChange(of: controller.running) { _, running in if running { login = nil } }
        .task {
            while !Task.isCancelled {
                await controller.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
}
