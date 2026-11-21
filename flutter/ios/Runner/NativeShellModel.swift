// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct NativePeer: Identifiable {
    let id: String
    let name: String
    let platform: String
    let favorite: Bool
    var forceRelay = false
    var hasPassword = false
    var username = ""
    var hostname = ""

    var symbol: String {
        let value = platform.lowercased()
        if value.contains("android") || value.contains("ios") { return "iphone" }
        if value.contains("mac") { return "laptopcomputer" }
        return "desktopcomputer"
    }
}

enum NativeSessionKind: String { case desktop, terminal, files, camera }

@available(iOS 17.0, *)
enum NativeSection: String, CaseIterable, Identifiable {
    case connection, favorites, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .connection: return "主页"
        case .favorites: return "收藏"
        case .settings: return "设置"
        }
    }
    var symbol: String {
        switch self {
        case .connection: return "house"
        case .favorites: return "star"
        case .settings: return "gearshape"
        }
    }
}

@available(iOS 17.0, *)
enum NativeSheet: String, Identifiable {
    case gestures, servers, pointer, scroll, resolution, connectionPrompt, account, scanner, sessionSettings, osPassword, downloads, quickDeviceSettings
    var id: Self { self }
}

@MainActor
final class NativeConnectionMetrics: ObservableObject {
    @Published var values: [String: String] = [:]
    @Published var frameResolution: NativeResolution?
    var receiveRate: String? {
        guard let value = values["speed"] else { return nil }
        return value.hasSuffix("kB/s") ? String(value.dropLast(4)) + " KiB/s" : value
    }
    func clear() { values = [:]; frameResolution = nil }
}

@available(iOS 17.0, *)
@MainActor
final class NativeShellModel: ObservableObject {
    private static let windows = NSHashTable<NativeShellModel>.weakObjects()
    let core: NativeCoreChannel
    var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.session.persistentIdentifier == core.window }?.windows.first
            ?? (core.window.isEmpty ? scenes.flatMap(\.windows).first(where: \.isKeyWindow) : nil)
    }
    private static func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = windows.allObjects.contains { $0.connected && ($0.settings["keep-awake-during-outgoing-sessions"] ?? true) }
    }
    lazy var terminalSession = NativeTerminalTabs(core: core)
    let shortcuts = NativeShortcutLibrary()
    @Published var fileBrowserMinimized = false
    lazy var fileBrowser = NativeFileModel(core: core)
    @Published var remoteKind = NativeSessionKind.desktop
    @Published var accountName = ""
    @Published var ready = false
    @Published var remoteID: String?
    @Published var connected = false
    @Published var remoteKeyboardVisible = false
    @Published var dockPosition = 1.0
    @Published var cursorSize = 28.0
    @Published var settings: [String: Bool] = [:]
    @Published var defaults: [String: String] = [:]
    @Published var otherDefaults: [[String: Any]] = []
    @Published var fixed: Set<String> = []
    @Published var codecs: [String: Bool] = [:]
    @Published var hideNetwork = false
    let tailscale = NativeTailscaleController.shared
    @Published var hideProxy = false
    @Published var proxy: [String] = []
    @Published var peers: [NativePeer] = []
    @Published var idText = ""
    @Published var password = ""
    @Published var forceRelay = false
    @Published var isConnecting = false
    @Published var inputMode = "mouse"
    @Published var showResolutionAdjustment = false
    @Published var showOSPassword = false
    @Published var showInputAdjustment = false
    @Published private(set) var limitZoomToWidth = UserDefaults.standard.bool(forKey: "native.limit-zoom-to-width")
    @Published var canvasLocked = UserDefaults.standard.bool(forKey: "native.default-canvas-lock")
    let connectionMetrics = NativeConnectionMetrics()
    var connectionStats: [String: String] { connectionMetrics.values }
    @Published var sessionToggles: [String: Bool] = [:]
    @Published var sessionQuality = "balanced"
    @Published var sessionCodec = "auto"
    @Published var sessionCodecs: [String: Bool] = [:]
    @Published var customQuality = 50.0
    @Published var customFPS = 30.0
    @Published var servers: [String: String] = [:]
    @Published var selected: NativeSection? = .connection
    @Published var sheet: NativeSheet?
    @Published var errorMessage: String?
    @Published var prompt: NativeConnectionMessage?
    @Published var confirmDisconnect = false
    @Published var connectionFailure: NativeConnectionMessage?
    @Published var remoteUsername = ""
    @Published var remoteHostname = ""
    @Published var displays: [NativeDisplay] = []
    @Published var resolutions: [NativeResolution] = []
    private var resolutionTask: Task<Void, Never>?
    var currentResolution: NativeResolution? { displays.first { $0.id == displayIndex }?.currentResolution }
    var resolutionChoices: [NativeResolution] {
        guard let currentResolution, !resolutions.contains(currentResolution) else { return resolutions }
        return [currentResolution] + resolutions
    }
    @Published var displayIndex = 0 {
        didSet {
            if oldValue != displayIndex {
                connectionMetrics.values.removeValue(forKey: "fps")
                connectionMetrics.frameResolution = nil
            }
        }
    }
    @Published var status = "正在连接…"
    var keyboardAllowed = true
    weak var canvas: NativeCanvasView?
    var cursor: NativeCursor?
    var lastFrame: (CGImage, Int)?
    var cursorPosition: CGPoint?
    var currentSessionID: String? { sessionID }
    private var sessionID: String?
    private var backgroundConnection: (id: String, kind: NativeSessionKind)?
    private var lastWindowConnection: (id: String, kind: NativeSessionKind)?
    private var eventTimer: Timer?
    private var automaticallyRetried = false

    init(window: String = "") {
        core = NativeCoreChannel(window: window)
        do {
            let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            apply(try core.call("initialize", ["directory": directory.path,
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
                "deviceName": UIDevice.current.name]))
        } catch { errorMessage = error.localizedDescription }
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in Task { @MainActor in self?.poll() } }
        RunLoop.main.add(timer, forMode: .common)
        eventTimer = timer
        Self.windows.add(self)
    }
    deinit { eventTimer?.invalidate(); resolutionTask?.cancel(); if !core.window.isEmpty { _ = try? core.call("releaseWindow") } }

    func apply(_ state: [String: Any]) {
        if let options = state["sessionSettings"] as? [String: Any] {
            sessionToggles = options["toggles"] as? [String: Bool] ?? [:]
            sessionQuality = options["quality"] as? String ?? "balanced"
            sessionCodec = options["codec"] as? String ?? "auto"
            sessionCodecs = options["codecs"] as? [String: Bool] ?? [:]
            if let custom = options["custom"] as? [Int], custom.count >= 2 { customQuality = Double(min(max(custom[0], 10), 100)); customFPS = custom[1] > 0 ? Double(min(max(custom[1], 5), 120)) : 30 }
            canvas?.updateCursor()
            return
        }
        if let proxy = state["proxy"] as? [String] { self.proxy = proxy; return }
        if let raw = state["accountUser"] as? String {
            let data = raw.data(using: .utf8) ?? Data()
            let user = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let displayName = user?["display_name"] as? String ?? ""
            accountName = displayName.isEmpty ? (user?["name"] as? String ?? "") : displayName
        }
        ready = state["ready"] as? Bool ?? ready
        cursorSize = state["cursorSize"] as? Double ?? cursorSize
        settings = state["settings"] as? [String: Bool] ?? settings
        defaults = state["defaults"] as? [String: String] ?? defaults
        otherDefaults = state["otherDefaults"] as? [[String: Any]] ?? otherDefaults
        if let fixed = state["fixed"] as? [String] { self.fixed = Set(fixed) }
        codecs = state["codecs"] as? [String: Bool] ?? codecs
        hideNetwork = state["hideNetwork"] as? Bool ?? hideNetwork
        hideProxy = state["hideProxy"] as? Bool ?? hideProxy
        inputMode = state["inputMode"] as? String ?? inputMode
        servers = state["servers"] as? [String: String] ?? servers
        if idText.isEmpty { idText = state["lastId"] as? String ?? "" }
        if let rows = state["peers"] as? [[String: Any]] {
            peers = rows.compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                return NativePeer(id: id, name: row["name"] as? String ?? id,
                    platform: row["platform"] as? String ?? "", favorite: row["favorite"] as? Bool ?? false,
                    forceRelay: row["forceRelay"] as? Bool ?? false, hasPassword: row["hasPassword"] as? Bool ?? false, username: row["username"] as? String ?? "", hostname: row["hostname"] as? String ?? "")
            }
        }
    }
    func cancelBackgroundRecovery() { backgroundConnection = nil }
    func prepareForBackground() {
        if connected, let remoteID, sessionID != nil {
            backgroundConnection = (remoteID, remoteKind)
        } else { backgroundConnection = nil }
    }
    func reconnectOnForeground() async {
        let previous = backgroundConnection
        backgroundConnection = nil
        guard let previous, UserDefaults.standard.bool(forKey: "native.foreground-reconnect"),
              !connected, !isConnecting, (prompt == nil || prompt?.connectionError == true), errorMessage == nil, !confirmDisconnect else { return }
        if let remoteID {
            guard remoteID == previous.id, remoteKind == previous.kind, sessionID != nil, connectionFailure != nil else { return }
            resumeConnection("reconnect")
        } else {
            await connect(to: previous.id, kind: previous.kind)
        }
    }
    func restoreOnLaunch() async {
        guard UserDefaults.standard.bool(forKey: "native.launch-restore"), remoteID == nil,
              !isConnecting, prompt == nil, errorMessage == nil, !confirmDisconnect else { return }
        await restoreLastSession()
    }
    private func restoreLastSession() async {
        if let last = lastWindowConnection {
            await connect(to: last.id, kind: last.kind)
        } else if let last = UserDefaults.standard.dictionary(forKey: "native.last-session"),
                  let id = last["id"] as? String, !id.isEmpty,
                  let mode = last["mode"] as? String, let kind = NativeSessionKind(rawValue: mode) {
            await connect(to: id, kind: kind)
        } else if let id = UserDefaults.standard.string(forKey: "native.last-desktop-id"), !id.isEmpty {
            await connect(to: id)
        }
    }
    func refresh() async { await send("refresh", showError: false) }
    func connect(to id: String? = nil, kind: NativeSessionKind = .desktop, approval: Bool = false, relay: Bool? = nil) async {
        guard ready, !isConnecting, remoteID == nil else { return }
        let remote = NativeLaunchLink.normalizedID(id ?? idText)
        guard !remote.isEmpty else { errorMessage = "请输入远程 ID"; return }
        isConnecting = true
        defer { isConnecting = false; password = "" }
        do {
            try await tailscale.prepareConnection(remote)
            try Task.checkCancellation()
            let response = try core.call("connect", ["id": remote, "forceRelay": relay ?? (forceRelay || (peers.first(where: { $0.id == remote })?.forceRelay ?? false)), "password": password, "mode": kind.rawValue, "loginMethod": approval ? "request-approval" : ""])
            automaticallyRetried = false
            resolutions = []; resolutionTask?.cancel()
            sessionID = response["session"] as? String
            remoteKind = kind; fileBrowserMinimized = false; terminalSession.reset(); fileBrowser.reset()
            idText = remote; remoteID = remote; connected = false; connectionFailure = nil
            remoteUsername = peers.first { $0.id == remote }?.username ?? ""
            remoteHostname = peers.first { $0.id == remote }?.hostname ?? ""
            sessionToggles = [:]; displayIndex = 0; displays = []; cursor = nil; keyboardAllowed = true; canvasLocked = UserDefaults.standard.bool(forKey: "native.default-canvas-lock"); connectionMetrics.clear()
            status = "正在连接…"
        } catch is CancellationError { }
        catch { errorMessage = error.localizedDescription }
    }
    func send(_ method: String, arguments: [String: Any] = [:], showError: Bool = true) async {
        do {
            switch method {
            case "disconnect": requestDisconnect()
            case "fit": canvas?.fit()
            case "original": canvas?.originalSize()
            case "zoom": canvas?.zoom(by: arguments["factor"] as? Double ?? 1)
            case "lockCanvas": canvasLocked = arguments["value"] as? Bool ?? false
            case "keyboard": canvas?.showSystemKeyboard()
            case "hideKeyboard": canvas?.hideSystemKeyboard()
            case "rightClick": canvas?.click(button: "right")
            case "sessionOption":
                if arguments["key"] as? String == "view-only" { canvas?.releaseInput() }
                apply(try core.call(method, arguments))
                if arguments["key"] as? String == "show-remote-cursor", let value = arguments["value"] as? Bool {
                    UserDefaults.standard.set(value, forKey: "native.show-remote-cursor")
                }
            default: apply(try core.call(method, arguments))
            }
        } catch { if showError { errorMessage = error.localizedDescription } }
    }
    func sendSavedOSPassword() {
        canvas?.hideSystemKeyboard()
        do {
            let settings = try core.call("osPasswordSettings")
            guard let password = settings["password"] as? String, !password.isEmpty else {
                errorMessage = "请先在自动登录中设置操作系统密码"
                return
            }
            _ = try core.call("saveOSPassword", ["session": settings["session"] as? String ?? "", "password": password, "send": true])
        } catch { errorMessage = error.localizedDescription }
    }

    func requestDisconnect() {
        showInputAdjustment = false; showResolutionAdjustment = false; showOSPassword = false
        if UserDefaults.standard.bool(forKey: "native.skip-disconnect-confirmation") { closeSession() }
        else { confirmDisconnect = true }
    }
    func closeSession(preservingBackgroundSession: Bool = false) {
        if !preservingBackgroundSession { backgroundConnection = nil }
        showInputAdjustment = false; showResolutionAdjustment = false; showOSPassword = false
        confirmDisconnect = false; connectionFailure = nil; connectionMetrics.clear()
        resolutions = []; resolutionTask?.cancel()
        if remoteKind == .terminal { terminalSession.end() }
        if fileBrowser.transferring { fileBrowser.cancel() }
        fileBrowserMinimized = false; fileBrowser.reset()
        canvas?.releaseInput(); canvas?.hideSystemKeyboard()
        do { apply(try core.call("disconnect")) } catch { errorMessage = error.localizedDescription }
        remoteKeyboardVisible = false
        sessionID = nil; remoteID = nil; connected = false; cursor = nil; lastFrame = nil; cursorPosition = nil; displays = []; prompt = nil; sheet = nil
        status = "正在连接…"
        Self.updateIdleTimer()
    }
    func peerAction(_ peer: NativePeer, _ action: String, value: Any = "") {
        do { apply(try core.call("peerAction", ["id": peer.id, "action": action, "value": value])) }
        catch { errorMessage = error.localizedDescription }
    }
    var drawLocalCursor: Bool {
        connected && sessionToggles["show-remote-cursor"] != false
            && !inputMode.hasPrefix("touch")
            && !(displays.first { $0.id == displayIndex }?.embeddedCursor ?? false)
    }
    func sessionToggle(_ key: String) -> Bool {
        if let value = sessionToggles[key] { return value }
        if key == "show-remote-cursor" { return UserDefaults.standard.object(forKey: "native.show-remote-cursor") as? Bool ?? true }
        return otherDefaults.first { $0["key"] as? String == key }?["value"] as? Bool ?? false
    }
    func sessionOption(_ key: String, _ value: Any) { Task { await send("sessionOption", arguments: ["key": key, "value": value]) } }
    func setMode(_ mode: String) { canvas?.releaseInput(); Task { await send("inputMode", arguments: ["value": mode]) } }
    func setting(_ key: String, _ value: Any) { Task { await send("setting", arguments: ["key": key, "value": value]) } }
    var remoteName: String { guard let id = remoteID else { return "SwiftRust" }; return peers.first(where: { $0.id == id })?.name ?? id }
    var remoteIdentity: String {
        let peer = peers.first { $0.id == remoteID }
        let user = remoteUsername.isEmpty ? (peer?.username ?? "") : remoteUsername
        let hostname = remoteHostname.isEmpty ? (peer?.hostname ?? "") : remoteHostname
        let host = hostname.isEmpty ? (remoteID ?? "远程设备") : hostname
        return user.isEmpty ? host : "\(user)@\(host)"
    }
    func firstFrame() {
        guard !connected else { return }
        connectionFailure = nil
        connected = true; status = "已连接"
        if sessionID != nil, let remoteID {
            lastWindowConnection = (remoteID, remoteKind)
            UserDefaults.standard.set(["id": remoteID, "mode": remoteKind.rawValue], forKey: "native.last-session")
        }
        if sessionID != nil && remoteKind == .desktop && !fixed.contains("show-remote-cursor") {
            let show = UserDefaults.standard.object(forKey: "native.show-remote-cursor") as? Bool ?? true
            do { apply(try core.call("sessionOption", ["key": "show-remote-cursor", "value": show])) }
            catch { errorMessage = error.localizedDescription }
        }
        if sheet == .connectionPrompt { sheet = nil; prompt = nil }
        Self.updateIdleTimer()
        if let state = try? core.call("refresh") { apply(state) }
    }
    func setLimitZoomToWidth(_ enabled: Bool) {
        limitZoomToWidth = enabled
        UserDefaults.standard.set(enabled, forKey: "native.limit-zoom-to-width")
        if enabled { canvas?.constrainZoomToWindowWidth() }
    }
    func changeResolution(_ resolution: NativeResolution) {
        resolutionTask?.cancel()
        guard remoteKind == .desktop, connected, keyboardAllowed, !sessionToggle("view-only"), let session = sessionID else { return }
        let display = displayIndex
        let core = core
        resolutionTask = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await core.changeResolution(session: session, display: display, resolution: resolution)
            } catch is CancellationError { }
            catch {
                if self?.sessionID == session, !Task.isCancelled { self?.errorMessage = error.localizedDescription }
            }
        }
    }
    func chooseDisplay(_ display: Int) {
        guard display != displayIndex else { return }
        do { _ = try core.call("display", ["index": display]); displayIndex = display; canvas?.prepareDisplay() }
        catch { errorMessage = error.localizedDescription }
    }
    func resumeConnection(_ method: String, _ args: [String: Any] = [:]) {
        showInputAdjustment = false; showResolutionAdjustment = false; showOSPassword = false
        do {
            connectionFailure = nil
            if method == "reconnect" { resolutionTask?.cancel(); connectionMetrics.clear(); connected = false; canvas?.prepareDisplay(); terminalSession.reset() }
            _ = try core.call(method, args)
            prompt = nil; sheet = nil; status = "等待远端响应…"
        } catch { errorMessage = error.localizedDescription }
    }
    private func promptPreferenceKey(_ prompt: NativeConnectionMessage) -> String? {
        guard let remoteID, prompt.insecure || prompt.connectionError else { return nil }
        return "native.skip-prompt.\(prompt.insecure ? "insecure" : "reconnect").\(remoteID)"
    }
    func promptIsSkipped(_ prompt: NativeConnectionMessage) -> Bool {
        guard let key = promptPreferenceKey(prompt) else { return false }
        return UserDefaults.standard.bool(forKey: key)
    }
    func setPromptSkipped(_ prompt: NativeConnectionMessage, _ skip: Bool) {
        if let key = promptPreferenceKey(prompt) { UserDefaults.standard.set(skip, forKey: key) }
    }
    func continuePrompt(_ prompt: NativeConnectionMessage, skip: Bool) {
        setPromptSkipped(prompt, skip)
        guard prompt.insecure || prompt.hasRetry else { self.prompt = nil; sheet = nil; return }
        resumeConnection(prompt.insecure ? "insecure" : "reconnect", prompt.insecure ? ["continue": true] : [:])
    }
    private func poll() {
        guard sessionID != nil else { return }
        do {
            let response = try core.call("poll")
            guard response["session"] as? String == sessionID else { return }
            for event in response["events"] as? [[String: Any]] ?? [] { handle(event) }
        } catch { errorMessage = error.localizedDescription }
    }
    func handle(_ event: [String: Any]) {
        let name = event["name"] as? String ?? ""
        switch name {
        case "peer_info", "sync_peer_info":
            if let username = event["username"] as? String, !username.isEmpty { remoteUsername = username }
            if let hostname = event["hostname"] as? String, !hostname.isEmpty { remoteHostname = hostname }
            if let encoded = event["displays"] as? String, let data = encoded.data(using: .utf8),
               let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                displays = rows.enumerated().map { index, row in
                    NativeDisplay(id: index, origin: CGPoint(x: row["x"] as? Int ?? 0, y: row["y"] as? Int ?? 0),
                        size: CGSize(width: row["width"] as? Int ?? 0, height: row["height"] as? Int ?? 0), embeddedCursor: NativeDisplay.cursorEmbedded(row["cursor_embedded"]),
                        originalResolution: { if let width = row["original_width"] as? Int, let height = row["original_height"] as? Int, width > 0, height > 0 { return NativeResolution(width: width, height: height) }; return nil }(),
                        customResolution: row["original_width"] as? Int == 0 && row["original_height"] as? Int == 0,
                        scale: { if let width = row["width"] as? Int, let scaled = row["scaled_width"] as? Int, scaled > 0 { return max(1, CGFloat(width) / CGFloat(scaled)) }; return 1 }())
                }
            }
            if let encoded = event["resolutions"] as? String { resolutions = NativeResolution.decode(encoded) }
            if let display = Int(event["current_display"] as? String ?? "") { displayIndex = display }
            status = "等待远端画面…"
            if remoteKind == .terminal {
                firstFrame(); terminalSession.open()
            } else if remoteKind == .files {
                if !connected { firstFrame(); fileBrowser.load("") }
            }
            if sheet == .connectionPrompt { sheet = nil; prompt = nil }
        case "update_quality_status":
            var values = connectionStats
            for key in ["speed", "codec_format", "chroma"] {
                if let value = event[key] as? String, !value.isEmpty { values[key] = String(value.prefix(80)) }
            }
            for key in ["delay", "target_bitrate"] {
                if let value = event[key] as? String, UInt64(value) != nil { values[key] = value }
            }
            if let encoded = event["fps"] as? String, let data = encoded.data(using: .utf8),
               let fps = try? JSONDecoder().decode([String: Double].self, from: data), !fps.isEmpty {
                if let current = fps[String(displayIndex)], current.isFinite, current >= 0 {
                    values["fps"] = String(format: "%.0f", current)
                } else { values.removeValue(forKey: "fps") }
            }
            if connectionMetrics.values != values { connectionMetrics.values = values }
        case "terminal_response": terminalSession.handle(event)
        case "file_dir", "empty_dirs", "job_progress", "job_done", "job_error", "override_file_confirm": fileBrowser.handle(event)
        case "permission":
            if let value = event["keyboard"] as? String {
                keyboardAllowed = value == "true"
                if !keyboardAllowed { canvas?.releaseInput() }
            }
        case "cursor_id", "native_cursor":
            if let id = event["id"] as? String, let shape = try? core.call("cursor", ["id": id]) {
                cursor = NativeRustCore.cursor(shape); canvas?.updateCursor()
            }
        case "cursor_position":
            canvas?.remoteCursor(CGPoint(x: Double(event["x"] as? String ?? "") ?? 0, y: Double(event["y"] as? String ?? "") ?? 0))
        case "switch_display":
            if let index = Int(event["display"] as? String ?? "") { displayIndex = index }
            if let encoded = event["resolutions"] as? String { resolutions = NativeResolution.decode(encoded) }
            if let index = displays.firstIndex(where: { $0.id == displayIndex }) {
                let old = displays[index]
                let width = Int(event["width"] as? String ?? "") ?? Int(old.size.width)
                let height = Int(event["height"] as? String ?? "") ?? Int(old.size.height)
                let originalWidth = Int(event["original_width"] as? String ?? "")
                let originalHeight = Int(event["original_height"] as? String ?? "")
                displays[index] = NativeDisplay(id: old.id,
                    origin: CGPoint(x: Int(event["x"] as? String ?? "") ?? Int(old.origin.x), y: Int(event["y"] as? String ?? "") ?? Int(old.origin.y)),
                    size: CGSize(width: width, height: height), embeddedCursor: NativeDisplay.cursorEmbedded(event["cursor_embedded"], fallback: old.embeddedCursor),
                    originalResolution: originalWidth.flatMap { w in originalHeight.flatMap { h in w > 0 && h > 0 ? NativeResolution(width: w, height: h) : nil } } ?? old.originalResolution,
                    customResolution: originalWidth == 0 && originalHeight == 0 || old.customResolution, scale: old.scale)
            }
            canvas?.prepareDisplay()
        case "msgbox":
            let type = event["type"] as? String ?? ""
            let title = event["title"] as? String ?? "连接提示"
            let text = event["text"] as? String ?? ""
            if type == "success" {
                if sheet == .connectionPrompt { prompt = nil; sheet = nil }
            } else if type == "connecting" || type == "restarting" || type.contains("wait-remote") {
                status = text.isEmpty ? "等待远端接受连接…" : text
            } else {
                showInputAdjustment = false; showResolutionAdjustment = false; showOSPassword = false
                canvas?.releaseInput()
                let message = NativeConnectionMessage(type: type, title: title, text: text, hasRetry: (event["hasRetry"] as? String == "true") || (event["hasRetry"] as? Bool == true), sourceTitle: event["sourceTitle"] as? String ?? "")
                if message.connectionError {
                    connectionFailure = message; connected = false
                    connectionMetrics.clear()
                    canvas?.hideSystemKeyboard(); canvas?.prepareDisplay()
                    status = text.isEmpty ? title : text
                }
                if promptIsSkipped(message) {
                    prompt = nil
                    if sheet == .connectionPrompt { sheet = nil }
                    if message.insecure {
                        resumeConnection("insecure", ["continue": true])
                    } else if message.hasRetry && !automaticallyRetried {
                        automaticallyRetried = true
                        resumeConnection("reconnect")
                    }
                } else {
                    prompt = message
                    if message.password || message.twoFactor { sheet = .connectionPrompt }
                    else if sheet == .connectionPrompt { sheet = nil }
                }
            }
        case "cancel_msgbox": if sheet == .connectionPrompt { sheet = nil; prompt = nil }
        default: break
        }
    }
}
