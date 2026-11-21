// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import Network
import Security

struct NativeSavedProxy: Codable, Equatable {
    let address: String
    let username: String
    let password: String
    private static let service = "me.airefactor.swiftrust.proxy"
    static func load() throws -> NativeSavedProxy? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: "configuration", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw NativeCoreError(message: "无法读取已保存的代理配置") }
        return try JSONDecoder().decode(Self.self, from: data)
    }
    func save() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service, kSecAttrAccount as String: "configuration"]
        let data = try JSONEncoder().encode(self)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NativeCoreError(message: "无法保存代理配置") }
    }
}

struct NativeProxyEndpoint: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case socks5, http, https
        var id: String { rawValue }
        var title: String { rawValue == "socks5" ? "SOCKS5" : rawValue.uppercased() }
        var defaultPort: Int { self == .socks5 ? 1080 : self == .http ? 80 : 443 }
    }
    let kind: Kind
    let host: String
    let port: UInt16
    var authority: String { "\(host.contains(":") ? "[\(host)]" : host):\(port)" }
    var url: String { "\(kind.rawValue)://\(authority)" }

    struct Invalid: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func parse(_ input: String, kind: Kind) throws -> Self {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitScheme = text.contains("://")
        let candidate = explicitScheme ? text : "\(kind.rawValue)://\(text)"
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }), !text.hasSuffix(":"),
              let components = URLComponents(string: candidate), let scheme = components.scheme?.lowercased(),
              let parsedKind = Kind(rawValue: scheme == "socks" ? "socks5" : scheme),
              var host = components.host, !host.isEmpty else {
            throw Invalid(message: "请填写域名或 IP 加端口，例如 proxy.example.com:1080。IPv6 请使用 [地址]:端口。")
        }
        guard components.user == nil, components.password == nil else {
            throw Invalid(message: "用户名和密码请填写在下方认证区域，不要放在代理地址中。")
        }
        guard (components.path.isEmpty || components.path == "/"), components.query == nil, components.fragment == nil else {
            throw Invalid(message: "代理地址只需服务器和端口，不要包含网页路径、查询参数或片段。")
        }
        guard let port = components.port ?? (explicitScheme ? parsedKind.defaultPort : nil),
              let portNumber = UInt16(exactly: port), portNumber > 0 else {
            throw Invalid(message: "请填写 1–65535 范围内的端口。")
        }
        if host.hasPrefix("["), host.hasSuffix("]") { host.removeFirst(); host.removeLast() }
        return Self(kind: parsedKind, host: host, port: portNumber)
    }
}

@MainActor
final class NativeProxyProbe: ObservableObject {
    @Published private(set) var testing = false
    @Published private(set) var milliseconds: Int?
    @Published private(set) var error: String?
    private var connection: NWConnection?
    private var timeout: Task<Void, Never>?

    func reset() {
        timeout?.cancel(); timeout = nil
        connection?.stateUpdateHandler = nil; connection?.cancel(); connection = nil
        testing = false; milliseconds = nil; error = nil
    }
    func start(_ endpoint: NativeProxyEndpoint) {
        reset(); testing = true
        let started = DispatchTime.now().uptimeNanoseconds
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            finish(milliseconds: nil, error: "无效端口"); return
        }
        let connection = NWConnection(host: NWEndpoint.Host(endpoint.host), port: port, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                guard let self, let connection, self.connection === connection else { return }
                switch state {
                case .ready:
                    self.finish(milliseconds: max(1, Int((DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)), error: nil)
                case .failed(let error), .waiting(let error):
                    self.finish(milliseconds: nil, error: error.localizedDescription)
                default: break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
        timeout = Task { [weak self, weak connection] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard let self, let connection, self.connection === connection else { return }
            self.finish(milliseconds: nil, error: "连接超时，请检查地址、端口和当前网络。")
        }
    }
    private func finish(milliseconds: Int?, error: String?) {
        reset(); self.milliseconds = milliseconds; self.error = error
    }
    deinit { connection?.cancel(); timeout?.cancel() }
}

@available(iOS 17.0, *)
struct NativeProxySettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var probe = NativeProxyProbe()
    @State private var kind = NativeProxyEndpoint.Kind.socks5
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var enabled = false
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enabled) { Label(NativeL("启用网络代理"), systemImage: "network") }
                    .tint(.green).disabled(loading || model.fixed.contains("proxy-url"))
                    .accessibilityIdentifier("native.proxyEnabled")
            } footer: { Text(NativeL("保存后生效。关闭代理会保留服务器与认证配置，重新开启无需重复填写。")) }
            Section {
                Picker(NativeL("代理类型"), selection: Binding(get: {
                    (try? NativeProxyEndpoint.parse(address, kind: kind))?.kind ?? kind
                }, set: { selected in
                    if address.contains("://"), let endpoint = try? NativeProxyEndpoint.parse(address, kind: kind) { address = endpoint.authority }
                    kind = selected
                })) {
                    ForEach(NativeProxyEndpoint.Kind.allCases) { kind in Text(kind.title).tag(kind) }
                }.accessibilityIdentifier("native.proxyKind")
                TextField(NativeL("域名或 IP:端口"), text: $address, prompt: Text("proxy.example.com:1080"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .accessibilityIdentifier("native.proxyAddress")
                    .onSubmit {
                        if let endpoint = normalized() { kind = endpoint.kind; address = endpoint.authority }
                    }
            } header: { Text(NativeL("代理服务器")) } footer: {
                Text(NativeL("填写域名或 IP 加端口，也可粘贴完整的代理 URL。HTTP 可以代理 HTTPS 目标；仅当代理服务器本身使用 TLS 时选择 HTTPS。"))
            }
            Section(NativeL("认证（可选）")) {
                TextField(NativeL("用户名"), text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(NativeL("密码"), text: $password)
            }
            Section {
                HStack {
                    Label(NativeL("代理连接延迟"), systemImage: "waveform.path.ecg")
                    Spacer()
                    if probe.testing { ProgressView().accessibilityLabel(NativeL("正在测试代理")) }
                    else if let milliseconds = probe.milliseconds {
                        Text("\(milliseconds) ms").monospacedDigit().foregroundStyle(.green)
                    } else { Text(probe.error == nil ? NativeL("未测试") : NativeL("连接失败")).foregroundStyle(.secondary) }
                }.accessibilityIdentifier("native.proxyLatency")
                Button(probe.testing ? NativeL("取消测试") : NativeL("测试连接延迟")) {
                    if probe.testing { probe.reset() }
                    else if let endpoint = normalized() { probe.start(endpoint) }
                }.disabled(loading || saving || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("native.testProxyLatency")
                if let message = probe.error { Text(NativeL(message)).font(.footnote).foregroundStyle(.red) }
            } footer: {
                Text(NativeL("测量本机到代理服务器的 DNS/TCP 建连耗时，不经过远程桌面。不验证代理协议、账号认证或 HTTPS 证书。服务器可达不代表代理已可用。"))
            }
            if let error { Section { Text(NativeL(error)).foregroundStyle(.red) } }
            Button(saving ? NativeL("保存中…") : NativeL("保存")) { save() }
                .disabled(loading || saving || model.fixed.contains("proxy-url"))
                .accessibilityIdentifier("native.saveProxy")
        }
        .disabled(saving)
        .navigationTitle(NativeL("网络代理")).navigationBarTitleDisplayMode(.inline)
        .task {
            await model.send("loadProxy")
            if model.proxy.count == 3 { address = model.proxy[0]; username = model.proxy[1]; password = model.proxy[2] }
            enabled = !address.isEmpty
            if !enabled {
                do {
                    if let saved = try NativeSavedProxy.load() { address = saved.address; username = saved.username; password = saved.password }
                } catch { self.error = error.localizedDescription }
            }
            if !address.isEmpty, let endpoint = normalized() { kind = endpoint.kind; address = endpoint.authority }
            model.proxy = []; loading = false
        }
        .onChange(of: address) { _, _ in probe.reset(); error = nil }
        .onChange(of: username) { _, _ in probe.reset() }
        .onChange(of: password) { _, _ in probe.reset() }
        .onChange(of: kind) { _, newKind in
            if address.contains("://"), let endpoint = try? NativeProxyEndpoint.parse(address, kind: newKind) { address = endpoint.authority }
            probe.reset()
        }
        .onDisappear { probe.reset(); password = ""; model.proxy = [] }
    }
    private func normalized() -> NativeProxyEndpoint? {
        do {
            let endpoint = try NativeProxyEndpoint.parse(address, kind: kind)
            error = nil
            return endpoint
        } catch { self.error = error.localizedDescription; return nil }
    }
    private func save() {
        let empty = address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let endpoint = empty ? nil : enabled ? normalized() : try? NativeProxyEndpoint.parse(address, kind: kind)
        guard !enabled || endpoint != nil else { return }
        probe.reset(); error = nil; saving = true
        let saved = NativeSavedProxy(address: endpoint?.url ?? address.trimmingCharacters(in: .whitespacesAndNewlines), username: empty ? "" : username, password: empty ? "" : password)
        do { try saved.save() } catch { self.error = error.localizedDescription; saving = false; return }
        let proxy = enabled ? saved.address : "", user = enabled ? saved.username : "", secret = enabled ? saved.password : ""
        Task {
            // The core's existing validation performs DNS. Keep it off the UI thread.
            let failure = await Task.detached(priority: .userInitiated) { () -> String? in
                do { _ = try NativeRustCore.call("saveProxy", ["proxy": proxy, "username": user, "password": secret]); return nil }
                catch { return error.localizedDescription }
            }.value
            saving = false
            if let failure { error = failure } else { dismiss() }
        }
    }
}
