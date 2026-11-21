// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import SwiftTerm
import UniformTypeIdentifiers

@available(iOS 17.0, *)
struct NativePeerRow: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    let peer: NativePeer
    private enum Confirmation {
        case rename, remove, forget
        var title: String {
            switch self {
            case .rename: return NativeL("重命名设备")
            case .remove: return NativeL("删除设备记录？")
            case .forget: return NativeL("清除已保存的密码？")
            }
        }
    }
    @State private var confirmation: Confirmation?
    @State private var name = ""
    @State private var launcher = false

    var body: some View {
        HStack(spacing: 10) {
            Button { connect(.desktop) } label: {
                HStack(spacing: 14) {
                    NativePeerBadge(peer: peer)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(peer.name).font(.headline).foregroundStyle(.primary)
                        Text(peer.id).font(.system(.subheadline, design: .rounded, weight: .medium).monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if peer.favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu { actions } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 23)).foregroundStyle(.secondary)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(NativeF("设备选项：%@", String(describing: peer.name)))
            .accessibilityIdentifier("native.peerMenu.\(peer.id)")
        }
        .foregroundStyle(.primary).padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .contextMenu { actions }
        .sheet(isPresented: $launcher) { NavigationStack { NativeDeviceLauncher(peer: peer).toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { launcher = false } } } } }
        .alert(confirmation?.title ?? "", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), presenting: confirmation) { action in
            switch action {
            case .rename:
                TextField(NativeL("设备名称"), text: $name)
                Button(NativeL("保存")) { model.peerAction(peer, "rename", value: name) }
            case .remove:
                Button(NativeL("删除记录"), role: .destructive) { model.peerAction(peer, "favorite", value: false); model.peerAction(peer, "remove") }
            case .forget:
                Button(NativeL("清除密码"), role: .destructive) { model.peerAction(peer, "forgetPassword") }
            }
            Button(NativeL("取消"), role: .cancel) { }
        } message: { action in
            if case .remove = action { Text(NativeL("不会删除远程设备上的文件。")) }
        }
    }

    @ViewBuilder private var actions: some View {
        Section(NativeL("连接方式")) {
            Button { connect(.desktop) } label: { Label(NativeL("远程控制"), systemImage: "display") }
            Button { connect(.files) } label: { Label(NativeL("传输文件"), systemImage: "folder") }
            Button { connect(.camera) } label: { Label(NativeL("查看摄像头"), systemImage: "video") }
            Button { connect(.terminal) } label: { Label(NativeL("终端"), systemImage: "terminal") }
            Menu {
                Button(NativeL("远程控制")) { connect(.desktop, approval: true) }
                Button(NativeL("传输文件")) { connect(.files, approval: true) }
                Button(NativeL("查看摄像头")) { connect(.camera, approval: true) }
                Button(NativeL("终端")) { connect(.terminal, approval: true) }
            } label: { Label(NativeL("请求批准"), systemImage: "hand.raised") }
            Toggle(isOn: Binding(get: { peer.forceRelay }, set: { model.peerAction(peer, "relay", value: $0) })) {
                Label(NativeL("强制中继连接"), systemImage: "network")
            }
        }
        Section(NativeL("设备管理")) {
            Button { launcher = true } label: { Label(NativeL("添加到主屏幕"), systemImage: "plus.app") }
            if UIApplication.shared.supportsMultipleScenes {
                Menu {
                    Button(NativeL("远程控制")) { openWindow(.desktop) }
                    Button(NativeL("终端")) { openWindow(.terminal) }
                    Button(NativeL("传输文件")) { openWindow(.files) }
                    Button(NativeL("查看摄像头")) { openWindow(.camera) }
                } label: { Label(NativeL("在新窗口连接"), systemImage: "macwindow.badge.plus") }
            }
            Button { name = peer.name; confirmation = .rename } label: { Label(NativeL("重命名"), systemImage: "pencil") }
            Button { model.peerAction(peer, "favorite", value: !peer.favorite) } label: {
                Label(peer.favorite ? NativeL("取消收藏") : NativeL("加入收藏"), systemImage: "star")
            }
            Button { confirmation = .forget } label: { Label(NativeL("清除已保存的密码"), systemImage: "key") }.disabled(!peer.hasPassword)
            Button(role: .destructive) { confirmation = .remove } label: { Label(NativeL("删除记录"), systemImage: "trash") }
        }
    }
    private func openWindow(_ kind: NativeSessionKind) {
        var link = NativeLaunchLink(id: peer.id, mode: kind); link.relay = peer.forceRelay || model.forceRelay
        NativeWindowLaunch.open(link) { model.errorMessage = $0 }
    }
    private func connect(_ kind: NativeSessionKind, approval: Bool = false) {
        Task { await model.connect(to: peer.id, kind: kind, approval: approval, relay: peer.forceRelay || model.forceRelay) }
    }
}

@available(iOS 17.0, *)
@MainActor final class NativeTerminalTabs: ObservableObject {
    private let core: NativeCoreChannel
    @Published var tabs: [NativeTerminalModel]
    init(core: NativeCoreChannel = NativeCoreChannel()) { self.core = core; tabs = [NativeTerminalModel(core: core)] }
    @Published private(set) var selectedID = 1
    private var nextID = 2
    var active: NativeTerminalModel { tabs.first { $0.id == selectedID } ?? tabs[0] }
    func select(_ tab: NativeTerminalModel) {
        guard tab.id != selectedID else { return }
        _ = active.view?.resignFirstResponder()
        selectedID = tab.id
    }
    func add(connected: Bool) {
        let tab = NativeTerminalModel(id: nextID, title: "终端 \(nextID)", core: core)
        nextID += 1; tabs.append(tab); select(tab)
        if connected { tab.open() }
    }
    func closeActive() {
        guard tabs.count > 1 else { return }
        let closing = active
        closing.end(); tabs.removeAll { $0.id == closing.id }
        selectedID = tabs[0].id
    }
    func reset() {
        for tab in tabs { _ = tab.view?.resignFirstResponder(); tab.reset() }
        tabs = [NativeTerminalModel(core: core)]; selectedID = 1; nextID = 2
    }
    func end() { for tab in tabs { tab.end() }; reset() }
    func open() { for tab in tabs { tab.open() } }
    func handle(_ event: [String: Any]) {
        let id = event["terminal_id"] as? Int ?? Int(event["terminal_id"] as? String ?? "")
        tabs.first { $0.id == id }?.handle(event)
    }
}

@available(iOS 17.0, *)
@MainActor final class NativeTerminalModel: ObservableObject, Identifiable {
    let id: Int
    @Published var title: String
    private let core: NativeCoreChannel
    init(id: Int = 1, title: String = "终端 1", core: NativeCoreChannel = NativeCoreChannel()) { self.id = id; self.title = title; self.core = core }
    @Published var status = "正在建立终端连接…"
    @Published var isOpen = false
    @Published var fontSize = 14.0
    @Published var keyboardVisible = false
    @Published var shortcutKeyboardVisible = false
    weak var view: NativeTerminalCanvas?
    private var started = false
    private var openRequested = false
    private var pending = Data()
    private var suppressResponse = false
    private var replay = false
    private var columns = 80
    private var rows = 24

    func reset() {
        started = false; openRequested = false; isOpen = false; pending.removeAll(); replay = false
        status = "正在建立终端连接…"
        view?.feed(text: "\u{1b}c\u{1b}[6 q")
    }
    func open() {
        openRequested = true
        if !started { status = "正在准备终端尺寸…" }
        openWhenLaidOut()
    }
    fileprivate func openWhenLaidOut() {
        guard openRequested, !started, let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
        view.layoutIfNeeded()
        let dimensions = view.getTerminal().getDims()
        guard dimensions.cols > 0, dimensions.rows > 0 else { return }
        columns = dimensions.cols; rows = dimensions.rows
        started = true; status = "正在打开远程 Shell…"
        call("terminalOpen", ["rows": rows, "cols": columns])
    }
    func input(_ value: String) {
        guard isOpen, !suppressResponse else { return }
        call("terminalInput", ["data": value])
    }
    func shortcut(_ key: String, modifiers: Set<String>) {
        if NativeTerminalKeys.isLocalCommand(key, modifiers: modifiers) {
            switch key {
            case "VK_C": copySelection()
            case "VK_V": if isOpen { view?.paste(nil) }
            case "VK_A": view?.selectAll(nil)
            default: break
            }
        } else if let sequence = NativeTerminalKeys.sequence(key, modifiers: modifiers, applicationCursor: view?.getTerminal().applicationCursor ?? false) {
            input(sequence)
        }
    }
    func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0 else { return }
        let changed = cols != columns || rows != self.rows
        columns = cols; self.rows = rows
        if isOpen && changed { status = "已连接 · \(cols) × \(rows)"; call("terminalResize", ["rows": rows, "cols": cols]) }
        if openRequested && !started { openWhenLaidOut() }
    }
    func attach(_ view: NativeTerminalCanvas) {
        self.view = view
        if !pending.isEmpty { feed(pending); pending.removeAll() }
    }
    func handle(_ event: [String: Any]) {
        let id = (event["terminal_id"] as? Int) ?? Int(event["terminal_id"] as? String ?? "")
        guard id == self.id else { return }
        switch event["type"] as? String {
        case "opened":
            isOpen = event["success"] as? Bool ?? (event["success"] as? String == "true")
            replay = event["replay_terminal_output"] as? Bool ?? (event["replay_terminal_output"] as? String == "true")
            status = isOpen ? "已连接 · \(columns) × \(rows)" : (event["message"] as? String ?? "终端打开失败")
            if isOpen {
                call("terminalResize", ["rows": rows, "cols": columns])
            } else { started = false; openRequested = false }
        case "data":
            if let encoded = event["data"] as? String, let data = Data(base64Encoded: encoded) {
                if view != nil { feed(data) }
                else { pending.append(data); if pending.count > 1_048_576 { pending.removeFirst(pending.count - 1_048_576) } }
            }
        case "closed":
            isOpen = false; started = false; openRequested = false
            status = "Shell 已结束 · 退出码 \(event["exit_code"].map { String(describing: $0) } ?? "0")"
        case "error":
            isOpen = false; started = false; openRequested = false; status = event["message"] as? String ?? "终端发生错误"
        default: break
        }
    }
    private func feed(_ data: Data) {
        suppressResponse = replay; replay = false
        view?.feed(byteArray: Array(data)[...])
        suppressResponse = false
    }
    func end() { if started { call("terminalClose") }; reset(); _ = view?.resignFirstResponder() }
    private func call(_ method: String, _ args: [String: Any] = [:]) {
        do { var args = args; args["terminalId"] = id; _ = try core.call(method, args) }
        catch { status = error.localizedDescription; if method == "terminalOpen" { started = false; openRequested = false } }
    }
    func copySelection() {
        if let selected = view?.getSelection(), !selected.isEmpty { UIPasteboard.general.string = selected }
    }
}

@available(iOS 17.0, *)
final class NativeTerminalCanvas: TerminalView, TerminalViewDelegate {
    weak var model: NativeTerminalModel?
    private weak var shellModel: NativeShellModel?
    private var shortcutWindowSize = CGSize.zero
    init(model: NativeTerminalModel, shellModel: NativeShellModel? = nil) {
        self.model = model; self.shellModel = shellModel
        super.init(frame: .zero)
        terminalDelegate = self
        font = .monospacedSystemFont(ofSize: model.fontSize, weight: .regular)
        nativeBackgroundColor = .black; nativeForegroundColor = UIColor(white: 0.92, alpha: 1)
        backgroundColor = .black
        contentInsetAdjustmentBehavior = .never
        contentInset = .zero; scrollIndicatorInsets = .zero
        inputAccessoryView = nil
        accessibilityIdentifier = "native.terminalCanvas"
        feed(text: "\u{1b}[6 q")
        model.attach(self)
    }
    required init?(coder: NSCoder) { nil }
    func showShortcutKeyboard() {
        guard let model, let shellModel else { return }
        let size = window?.bounds.size ?? bounds.size
        let height = min(size.width, size.height) < 550 ? max(240, size.height * 0.45)
            : (size.width > size.height ? max(200, size.height * 0.39) : max(240, size.height * 0.375))
        shortcutWindowSize = size
        inputAccessoryView = nil
        inputView = NativeShortcutInputView(model: shellModel, height: height, width: size.width, terminal: model)
        model.shortcutKeyboardVisible = true
        if isFirstResponder { reloadInputViews() } else { _ = becomeFirstResponder() }
    }
    func showSystemKeyboard() {
        let replacing = inputView != nil
        inputView = nil; inputAccessoryView = nil
        model?.shortcutKeyboardVisible = false
        if isFirstResponder { if replacing { reloadInputViews() } } else { _ = becomeFirstResponder() }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if isFirstResponder, inputView is NativeShortcutInputView, let size = window?.bounds.size, size != shortcutWindowSize { showShortcutKeyboard() }
    }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { model?.keyboardVisible = true; model?.shortcutKeyboardVisible = inputView is NativeShortcutInputView }
        return accepted
    }
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { model?.keyboardVisible = false; model?.shortcutKeyboardVisible = false }
        return accepted
    }
    override func copy(_ sender: Any?) { model?.copySelection() }
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor [weak model] in model?.resize(cols: newCols, rows: newRows) }
    }
    func setTerminalTitle(source: TerminalView, title: String) { }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) { }
    func send(source: TerminalView, data: ArraySlice<UInt8>) { model?.input(String(decoding: data, as: UTF8.self)) }
    func scrolled(source: TerminalView, position: Double) { }
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) { }
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) { }
}

@available(iOS 17.0, *)
private struct NativeTerminalRenderer: UIViewRepresentable {
    @ObservedObject var terminal: NativeTerminalModel
    var shell: NativeShellModel?
    func makeUIView(context: Context) -> NativeTerminalCanvas { NativeTerminalCanvas(model: terminal, shellModel: shell) }
    func updateUIView(_ view: NativeTerminalCanvas, context: Context) {
        if view.font.pointSize != terminal.fontSize { view.font = .monospacedSystemFont(ofSize: terminal.fontSize, weight: .regular) }
    }
}

@available(iOS 17.0, *)
struct NativeTerminalScreen: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @ObservedObject private var sessions: NativeTerminalTabs
    init(model: NativeShellModel) {
        self.model = model
        _sessions = ObservedObject(wrappedValue: model.terminalSession)
    }
    var body: some View { NativeTerminalContent(model: model, sessions: sessions, terminal: sessions.active) }
}

@available(iOS 17.0, *)
private struct NativeTerminalContent: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @ObservedObject var sessions: NativeTerminalTabs
    @ObservedObject var terminal: NativeTerminalModel
    @State private var renameTarget: NativeTerminalModel?
    @State private var renameText = ""
    var body: some View {
        GeometryReader { geometry in
            let camera = NativeSessionContent.cameraFrame(in: geometry, window: model.window)
            let windowInsets = model.window?.safeAreaInsets ?? .zero
            let top = max(max(geometry.safeAreaInsets.top, windowInsets.top) + 8, camera.maxY - 20 - 52)
            VStack(spacing: 0) {
                header.padding(.leading, geometry.safeAreaInsets.leading).padding(.trailing, geometry.safeAreaInsets.trailing)
                    .padding(.top, top).background(.regularMaterial).zIndex(1)
                ZStack {
                    ForEach(sessions.tabs) { tab in
                        NativeTerminalRenderer(terminal: tab, shell: model)
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in tab.openWhenLaidOut() }
                            .opacity(tab.id == sessions.selectedID ? 1 : 0)
                            .allowsHitTesting(tab.id == sessions.selectedID)
                            .accessibilityHidden(tab.id != sessions.selectedID)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped().background(.black)
                if !terminal.shortcutKeyboardVisible {
                    NativeTerminalShortcuts(terminal: terminal, accessory: terminal.keyboardVisible)
                        .frame(width: geometry.size.width).background(.black)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
        .background(.black).tint(.primary)
        .alert(NativeL("重命名标签"), isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField(NativeL("标签名称"), text: $renameText)
            Button(NativeL("保存")) {
                let title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { renameTarget?.title = title }
                renameTarget = nil
            }
            Button(NativeL("取消"), role: .cancel) { renameTarget = nil }
        }
    }
    private var header: some View {
        HStack(spacing: 4) {
            Button { Task { await model.send("disconnect") } } label: { Image(systemName: "chevron.left").frame(width: 40, height: 40) }
                .accessibilityLabel(NativeL("断开终端连接"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sessions.tabs) { tab in
                        NativeTerminalTabLabel(tab: tab, selected: tab.id == sessions.selectedID) { sessions.select(tab) }
                            .simultaneousGesture(LongPressGesture().onEnded { _ in renameTarget = tab; renameText = tab.title })
                    }
                }
            }
            Button { sessions.add(connected: model.connected) } label: {
                Image(systemName: "plus").frame(width: 36, height: 40)
            }.accessibilityLabel(NativeL("新增标签页"))
            Menu {
                Text(NativeL(model.connected ? terminal.status : model.status))
                if model.connectionFailure?.hasRetry == true { Button(NativeL("重新连接"), systemImage: "arrow.clockwise") { model.resumeConnection("reconnect") } }
                Button(NativeL("复制所选文本"), systemImage: "doc.on.doc") { terminal.copySelection() }
                Button(NativeL("粘贴"), systemImage: "doc.on.clipboard") { terminal.view?.paste(nil) }.disabled(!terminal.isOpen)
                Button(NativeL("显示键盘"), systemImage: "keyboard") { terminal.view?.showSystemKeyboard() }
                Button(NativeL("快捷键盘"), systemImage: "command") { terminal.view?.showShortcutKeyboard() }
                Button(NativeL("隐藏键盘"), systemImage: "keyboard.chevron.compact.down") { _ = terminal.view?.resignFirstResponder() }
                Button(NativeL("增大字号"), systemImage: "textformat.size.larger") { terminal.fontSize = min(26, terminal.fontSize + 1) }
                Button(NativeL("缩小字号"), systemImage: "textformat.size.smaller") { terminal.fontSize = max(10, terminal.fontSize - 1) }
                Button(NativeL("重命名标签"), systemImage: "pencil") { renameTarget = terminal; renameText = terminal.title }
                Button(NativeL("关闭当前标签"), systemImage: "xmark") { sessions.closeActive() }.disabled(sessions.tabs.count <= 1)
                if !terminal.isOpen { Button(NativeL("重新打开 Shell"), systemImage: "arrow.clockwise") { terminal.open() }.disabled(!model.connected) }
            } label: { Image(systemName: "gearshape").font(.system(size: 21, weight: .regular)).frame(width: 40, height: 40) }
                .accessibilityLabel(NativeL("终端菜单"))
        }.buttonStyle(.plain).padding(.horizontal, 8).padding(.vertical, 6).frame(height: 52)
    }
}

@available(iOS 17.0, *)
private struct NativeTerminalTabLabel: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var tab: NativeTerminalModel
    let selected: Bool
    let select: () -> Void
    var body: some View {
        Button(action: select) {
            Text(tab.title).font(.subheadline.weight(selected ? .semibold : .regular)).lineLimit(1)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.horizontal, 12).frame(height: 36)
                .background(selected ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.accessibilityIdentifier("native.terminalTab.\(tab.id)")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

@available(iOS 17.0, *)
private struct NativeTerminalShortcuts: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var terminal: NativeTerminalModel
    var accessory = false
    var body: some View { shortcutBar.frame(maxWidth: .infinity).frame(height: 40) }
    @ViewBuilder private var shortcutBar: some View {
        shortcutKeys
    }
    private var shortcutKeys: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    key("Esc", "\u{1b}"); key("Tab", "\t"); key("Ctrl-C", "\u{03}"); key("Ctrl-D", "\u{04}")
                    key("↑", "\u{1b}[A"); key("↓", "\u{1b}[B"); key("←", "\u{1b}[D"); key("→", "\u{1b}[C")
                }
            }
            Button { terminal.view?.showShortcutKeyboard() } label: {
                Image(systemName: "command").foregroundStyle(.primary)
            }.accessibilityLabel(NativeL("终端快捷键盘")).accessibilityIdentifier("native.terminalShortcutKeyboard")
            Button {
                if accessory { _ = terminal.view?.resignFirstResponder() }
                else { terminal.view?.showSystemKeyboard() }
            } label: {
                Image(systemName: accessory ? "keyboard.chevron.compact.down" : "keyboard").foregroundStyle(.primary)
            }.accessibilityLabel(accessory ? NativeL("收起终端键盘") : NativeL("终端键盘"))
        }.buttonStyle(NativeTerminalShortcutStyle()).padding(.horizontal, 10).padding(.vertical, 6)

    }
    private func key(_ label: String, _ text: String) -> some View {
        Button { terminal.input(text) } label: {
            Text(NativeL(label)).foregroundStyle(.primary)
        }.font(.system(.subheadline, design: .monospaced)).disabled(!terminal.isOpen)
    }
}

@available(iOS 17.0, *)
private struct NativeTerminalShortcutStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.primary)
            .padding(.horizontal, 12).frame(minHeight: 28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? configuration.isPressed ? 0.7 : 1 : 0.45)
    }
}

@available(iOS 17.0, *)
struct NativeRemoteFile: Identifiable, Sendable {
    let name: String
    let size: Int64
    let directory: Bool
    let modified: UInt64
    init(name: String, size: Int64, directory: Bool, modified: UInt64 = 0) {
        self.name = name; self.size = size; self.directory = directory; self.modified = modified
    }
    var id: String { name }
}

@available(iOS 17.0, *)
struct NativeRemoteDirectory: Sendable {
    let jobID: Int
    let path: String
    let entries: [NativeRemoteFile]
    static func decode(_ value: String) throws -> NativeRemoteDirectory {
        guard let data = value.data(using: .utf8),
              let directory = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = directory["path"] as? String,
              let rows = directory["entries"] as? [[String: Any]] else {
            throw NativeCoreError(message: "目录数据格式无效，请刷新重试")
        }
        let entries = rows.compactMap { row -> NativeRemoteFile? in
            guard let name = row["name"] as? String, name != ".", name != ".." else { return nil }
            let type = (row["entry_type"] as? Int) ?? Int(row["entry_type"] as? String ?? "") ?? 0
            return NativeRemoteFile(name: name, size: (row["size"] as? NSNumber)?.int64Value ?? 0, directory: type < 4, modified: (row["modified_time"] as? NSNumber)?.uint64Value ?? 0)
        }.sorted { a, b in a.directory != b.directory ? a.directory : a.name.localizedStandardCompare(b.name) == .orderedAscending }
        return NativeRemoteDirectory(jobID: (directory["id"] as? Int) ?? Int(directory["id"] as? String ?? "") ?? 0, path: path, entries: entries)
    }
}

enum NativeUploadPreparation {
    static func copy(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let local = folder.appendingPathComponent(url.lastPathComponent)
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
                do { try FileManager.default.copyItem(at: source, to: local) }
                catch { copyError = error }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            return local
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}

struct NativeDownloadSource: Codable, Equatable, Sendable {
    let peer: String
    let path: String
    let size: Int64
    let modified: UInt64
    var directory: Bool? = nil
    static let metadataName = ".swiftrust-source.json"
}

struct NativeDownloadedFile: Identifiable, Sendable {
    let url: URL
    let size: Int64
    let date: Date
    let source: NativeDownloadSource?
    var directory: Bool { source?.directory == true }
    var id: URL { url }
    static func readAll() throws -> [NativeDownloadedFile] {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        var result: [NativeDownloadedFile] = []
        for folder in folders {
            for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey, .isDirectoryKey]) {
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isRegularFileKey, .isDirectoryKey])
                if values.isRegularFile == true || values.isDirectory == true, file.lastPathComponent != ".swiftrust-incomplete", file.lastPathComponent != NativeDownloadSource.metadataName {
                    guard !FileManager.default.fileExists(atPath: folder.appendingPathComponent(".swiftrust-incomplete").path) else { continue }
                    let source = (try? Data(contentsOf: folder.appendingPathComponent(NativeDownloadSource.metadataName))).flatMap { try? JSONDecoder().decode(NativeDownloadSource.self, from: $0) }
                    result.append(NativeDownloadedFile(url: file, size: Int64(values.fileSize ?? 0), date: values.creationDate ?? .distantPast, source: source))
                }
            }
        }
        return result.sorted { $0.date > $1.date }
    }
}

enum NativeEmptyDownloadFolders {
    static func create(_ value: String, remoteRoot: String, localRoot: URL) throws -> Bool {
        let data = Data(value.utf8)
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = response["path"] as? String,
              let folders = response["empty_dirs"] as? [[String: Any]] else { throw NativeCoreError(message: "目录数据格式无效，请刷新重试") }
        func normalized(_ path: String) -> String { path.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        let root = normalized(remoteRoot)
        guard normalized(path) == root else { return false }
        let localPath = localRoot.resolvingSymlinksInPath().path
        let destinations: [URL] = try folders.map { folder in
            guard let path = folder["path"] as? String else { throw NativeCoreError(message: "无效的目录路径") }
            let remote = normalized(path)
            guard remote == root || remote.hasPrefix(root + "/") else { throw NativeCoreError(message: "无效的目录路径") }
            let relative = remote == root ? "" : String(remote.dropFirst(root.count + 1))
            let components = relative.split(separator: "/", omittingEmptySubsequences: false)
            guard relative.isEmpty || components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains(":") && !$0.contains("\0") }) else { throw NativeCoreError(message: "无效的目录路径") }
            let destination = localRoot.appendingPathComponent(relative, isDirectory: true)
            let resolved = destination.resolvingSymlinksInPath().path
            guard resolved == localPath || resolved.hasPrefix(localPath + "/") else { throw NativeCoreError(message: "无效的目录路径") }
            return destination
        }
        for destination in destinations { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
        return true
    }
}

struct NativeFileOverwrite: Identifiable {
    let id: Int
    let file: Int
    let upload: Bool
}

@available(iOS 17.0, *)
struct NativeDownloadRequest: Identifiable {
    let file: NativeRemoteFile
    let source: NativeDownloadSource
    var id: String { source.peer + "\n" + source.path }
}

@available(iOS 17.0, *)
struct NativeRemoteDeleteTarget {
    let file: NativeRemoteFile
    let path: String
    static func descendant(_ name: String, root: String) throws -> String {
        let relative = name.replacingOccurrences(of: "\\", with: "/")
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard !relative.hasPrefix("/"), parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains(":") && !$0.contains("\0") }) else {
            throw NativeCoreError(message: "远端返回了无效的文件路径，删除已停止")
        }
        let separator = root.contains("\\") ? "\\" : "/"
        return root + (root.hasSuffix(separator) ? "" : separator) + parts.joined(separator: separator)
    }
}

@available(iOS 17.0, *)
struct NativeRemoteDeleteConfirmation: Identifiable {
    let id = UUID()
    let targets: [NativeRemoteDeleteTarget]
    let session: String
}

@available(iOS 17.0, *)
@MainActor final class NativeFileModel: ObservableObject {
    private let core: NativeCoreChannel
    init(core: NativeCoreChannel = NativeCoreChannel()) { self.core = core }
    @Published var path = ""
    @Published var entries: [NativeRemoteFile] = []
    @Published var status = "等待远端连接…"
    @Published var loading = false
    @Published var transferring = false
    @Published var deleting = false
    @Published var lastDeleteError = ""
    @Published var deletingLocalDownloads = false
    @Published var localDownloadDeletionError = ""
    @Published var downloads: [NativeDownloadedFile] = []
    @Published var pendingDownloads: [NativeDownloadRequest] = []
    @Published var downloadName = ""
    @Published var downloadSize: Int64 = 0
    @Published var downloadFinished: Int64 = 0
    var isDownloading: Bool { transferring && (downloadTarget != nil || downloadTask != nil) }
    @Published var downloadedURL: URL?
    @Published var overwrite: NativeFileOverwrite?
    private var emptyFolderTask: Task<Void, Never>?
    private var waitingForEmptyFolders = false
    private var folderTransferFinished = false
    private var activeDownloadSource: NativeDownloadSource?
    private var downloadTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var directoryTask: Task<Void, Never>?
    private var job = 0
    private var activeDeleteJob: Int?
    private var deleteSession = ""
    private var deleteQueue: [NativeRemoteDeleteTarget] = []
    private var deleteTarget: NativeRemoteDeleteTarget?
    private var deletePaths: [String] = []
    private var deleteIndex = 0
    private var removingEmptyDirectories = false
    private var activeJob: Int?
    private var downloadTarget: URL?
    private var uploadDirectory: URL?

    func reset() {
        stopDeleting()
        emptyFolderTask?.cancel(); emptyFolderTask = nil; waitingForEmptyFolders = false; folderTransferFinished = false
        pendingDownloads = []; activeDownloadSource = nil
        downloadTask?.cancel(); downloadTask = nil
        uploadTask?.cancel(); uploadTask = nil
        directoryTask?.cancel(); directoryTask = nil
        path = ""; entries = []; status = "等待远端连接…"; loading = false; transferring = false
        downloadName = ""; downloadFinished = 0; downloadSize = 0; lastDeleteError = ""
        activeJob = nil; downloadedURL = nil; downloadTarget = nil; overwrite = nil; cleanupUpload()
    }
    func load(_ path: String) {
        guard !loading, !deleting else { return }
        loading = true; status = "正在读取目录…"
        do { _ = try core.call("fileList", ["path": path, "hidden": false]) }
        catch { loading = false; status = error.localizedDescription }
    }
    func child(_ name: String) -> String {
        if path.hasSuffix("/") || path.hasSuffix("\\") { return path + name }
        return path + (path.contains("\\") ? "\\" : "/") + name
    }
    func parent() {
        var value = path
        while value.count > 1 && (value.hasSuffix("/") || value.hasSuffix("\\")) { value.removeLast() }
        if let slash = value.lastIndex(where: { $0 == "/" || $0 == "\\" }) {
            let index = value.distance(from: value.startIndex, to: slash)
            load(index == 0 ? "/" : String(value[...slash]))
        }
    }
    func download(_ file: NativeRemoteFile, peer: String = "") { download([file], peer: peer) }
    func download(_ files: [NativeRemoteFile], peer: String) {
        guard !deleting, !transferring || isDownloading else { return }
        for file in files {
            let source = NativeDownloadSource(peer: peer, path: child(file.name), size: file.size, modified: file.modified, directory: file.directory ? true : nil)
            let request = NativeDownloadRequest(file: file, source: source)
            if (!transferring || activeDownloadSource != source), !pendingDownloads.contains(where: { $0.id == request.id }) { pendingDownloads.append(request) }
        }
        startNextDownload()
    }
    func startNextDownload() {
        guard !transferring, !pendingDownloads.isEmpty else { return }
        let request = pendingDownloads.removeFirst()
        let file = request.file; let source = request.source
        activeDownloadSource = source
        transferring = true; status = "正在检查已下载文件…"
        downloadName = file.name; downloadSize = file.size; downloadFinished = 0
        downloadTask = Task { [weak self] in
            do {
                let records = try await Task.detached(priority: .utility) { try NativeDownloadedFile.readAll() }.value
                guard !Task.isCancelled, let self else { return }
                self.downloads = records; self.downloadTask = nil
                if !file.directory, let existing = records.first(where: { $0.source == source && $0.size == file.size }) {
                    self.downloadedURL = existing.url; self.transferring = false; self.status = "文件已下载，无需重复下载"
                    self.startNextDownload()
                    return
                }
                self.startDownload(file, source: source)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.transferring = false; self.downloadTask = nil; self.status = error.localizedDescription
            }
        }
    }
    private func startDownload(_ file: NativeRemoteFile, source: NativeDownloadSource) {
        do {
            let folder = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = file.name.replacingOccurrences(of: "\\", with: "/").components(separatedBy: "/").last ?? "download"
            guard !safeName.isEmpty, safeName != ".", safeName != ".." else { status = "文件名无效"; transferring = false; return }
            try Data().write(to: folder.appendingPathComponent(".swiftrust-incomplete"))
            try JSONEncoder().encode(source).write(to: folder.appendingPathComponent(NativeDownloadSource.metadataName), options: .atomic)
            downloadName = safeName; downloadSize = file.size; downloadFinished = 0
            downloadTarget = folder.appendingPathComponent(safeName); downloadedURL = nil
            if file.directory, let downloadTarget { try FileManager.default.createDirectory(at: downloadTarget, withIntermediateDirectories: true) }
            waitingForEmptyFolders = file.directory; folderTransferFinished = false
            try transfer(from: source.path, to: downloadTarget?.path ?? "", download: true, directory: file.directory)
            if file.directory {
                let currentJob = activeJob
                emptyFolderTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(20)) } catch { return }
                    guard let self, self.activeJob == currentJob, self.waitingForEmptyFolders else { return }
                    self.cancel(); self.status = "远端未返回空目录信息，文件夹下载未完成"
                }
            }
        } catch { status = error.localizedDescription; transferring = false }
    }
    func reloadDownloads() async {
        do { downloads = try await Task.detached(priority: .utility) { try NativeDownloadedFile.readAll() }.value }
        catch { status = error.localizedDescription }
    }
    func deleteDownload(_ file: NativeDownloadedFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            downloads.removeAll { $0.id == file.id }
            if downloadedURL == file.url { downloadedURL = nil }
        } catch { status = error.localizedDescription }
    }
    func deleteDownloads(_ ids: Set<URL>) async {
        guard !deletingLocalDownloads else { return }
        let targets = downloads.filter { ids.contains($0.id) }
        deletingLocalDownloads = true; localDownloadDeletionError = ""
        let result = await Task.detached(priority: .utility) {
            var deleted: Set<URL> = []
            var errors: [String] = []
            for file in targets {
                do { try FileManager.default.removeItem(at: file.url); deleted.insert(file.id) }
                catch { errors.append(file.url.lastPathComponent + ": " + error.localizedDescription) }
            }
            return (deleted, errors)
        }.value
        downloads.removeAll { result.0.contains($0.id) }
        if let downloadedURL, result.0.contains(downloadedURL) { self.downloadedURL = nil }
        localDownloadDeletionError = result.1.joined(separator: "\n")
        deletingLocalDownloads = false
    }
    func upload(_ url: URL) {
        guard !deleting, !transferring, !loading else { return }
        downloadTarget = nil
        transferring = true; status = "正在准备上传…"
        let destination = child(url.lastPathComponent)
        uploadTask = Task { [weak self] in
            do {
                let local = try await Task.detached(priority: .userInitiated) {
                    try NativeUploadPreparation.copy(url)
                }.value
                guard !Task.isCancelled, let self else {
                    try? FileManager.default.removeItem(at: local.deletingLastPathComponent())
                    return
                }
                self.uploadDirectory = local.deletingLastPathComponent()
                self.downloadTarget = nil
                try self.transfer(from: local.path, to: destination, download: false)
                self.uploadTask = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.status = error.localizedDescription; self.transferring = false
                self.activeJob = nil; self.uploadTask = nil; self.cleanupUpload()
            }
        }
    }
    private func transfer(from: String, to: String, download: Bool, directory: Bool = false) throws {
        job += 1; activeJob = job; transferring = true; status = download ? "正在下载…" : "正在上传…"
        _ = try core.call("fileTransfer", ["job": job, "from": from, "to": to, "download": download, "hidden": directory, "directory": directory])
    }
    func cancel() {
        emptyFolderTask?.cancel(); emptyFolderTask = nil; waitingForEmptyFolders = false; folderTransferFinished = false
        pendingDownloads = []; activeDownloadSource = nil
        downloadTask?.cancel(); downloadTask = nil
        uploadTask?.cancel(); uploadTask = nil
        if let activeJob {
            do { _ = try core.call("fileCancel", ["job": activeJob]) }
            catch { status = error.localizedDescription; return }
        }
        activeJob = nil; transferring = false; overwrite = nil; status = "传输已取消"; cleanupUpload()
    }
    func delete(_ confirmation: NativeRemoteDeleteConfirmation) {
        guard !loading, !transferring, pendingDownloads.isEmpty, !deleting else { status = "请先完成目录读取或传输"; return }
        lastDeleteError = ""
        deleteSession = confirmation.session; deleteQueue = confirmation.targets
        deleting = true; startNextDelete()
    }
    func stopDeleting() {
        if let activeDeleteJob { do { _ = try core.call("fileCancel", ["job": activeDeleteJob]) } catch { status = error.localizedDescription } }
        activeDeleteJob = nil; deleting = false; deleteQueue = []; deleteTarget = nil; deletePaths = []
        status = "删除已停止"
    }
    private func startNextDelete() {
        if deleteTarget?.file.directory == true, let activeDeleteJob {
            do { _ = try core.call("fileCancel", ["job": activeDeleteJob]) }
            catch { stopDeleting(); lastDeleteError = error.localizedDescription; return }
        }
        guard !deleteQueue.isEmpty else { deleting = false; activeDeleteJob = nil; status = "删除完成"; load(path); return }
        deleteTarget = deleteQueue.removeFirst(); deletePaths = []; deleteIndex = 0; removingEmptyDirectories = false
        job += 1; activeDeleteJob = job
        guard let target = deleteTarget else { return }
        status = "正在删除：" + target.file.name
        if target.file.directory { deleteCommand("list", path: target.path) }
        else { deletePaths = [target.path]; deleteCommand("file", path: target.path) }
    }
    private func deleteCommand(_ operation: String, path: String) {
        guard let activeDeleteJob else { return }
        do { _ = try core.call("fileDelete", ["session": deleteSession, "confirmed": true, "job": activeDeleteJob, "operation": operation, "path": path, "file": deleteIndex]) }
        catch { stopDeleting(); lastDeleteError = error.localizedDescription; status = error.localizedDescription }
    }
    private func continueDeleting() {
        guard let target = deleteTarget else { return }
        if deleteIndex < deletePaths.count { deleteCommand("file", path: deletePaths[deleteIndex]) }
        else if target.file.directory && !removingEmptyDirectories {
            removingEmptyDirectories = true; deleteCommand("emptyDirectories", path: target.path)
        } else { startNextDelete() }
    }
    func confirmOverwrite(_ value: NativeFileOverwrite) {
        do {
            _ = try core.call("fileOverride", ["job": value.id, "file": value.file, "replace": true, "upload": value.upload])
            overwrite = nil
        } catch { status = error.localizedDescription }
    }
    func handle(_ event: [String: Any]) {
        let name = event["name"] as? String ?? ""
        if name == "empty_dirs", waitingForEmptyFolders, let source = activeDownloadSource, let target = downloadTarget, let value = event["value"] as? String {
            let currentJob = activeJob
            Task { [weak self] in
                do {
                    let matched = try await Task.detached(priority: .utility) { try NativeEmptyDownloadFolders.create(value, remoteRoot: source.path, localRoot: target) }.value
                    guard let self, self.activeJob == currentJob, matched else { return }
                    self.emptyFolderTask?.cancel(); self.emptyFolderTask = nil; self.waitingForEmptyFolders = false
                    if self.folderTransferFinished { self.finishDownloadJob() }
                } catch {
                    guard let self, self.activeJob == currentJob else { return }
                    self.cancel(); self.status = error.localizedDescription
                }
            }
            return
        }
        if name == "file_dir" {
            guard event["is_local"] as? String != "true" else { return }
            directoryTask?.cancel()
            guard let value = event["value"] as? String else {
                loading = false; status = "目录数据格式无效，请刷新重试"; return
            }
            directoryTask = Task { [weak self] in
                do {
                    try Task.checkCancellation()
                    let directory = try await Task.detached(priority: .userInitiated) { try NativeRemoteDirectory.decode(value) }.value
                    try Task.checkCancellation()
                    guard let self else { return }
                    if directory.jobID > 0 {
                        if directory.jobID == self.activeDeleteJob, let target = self.deleteTarget {
                            self.deletePaths = try directory.entries.map { try NativeRemoteDeleteTarget.descendant($0.name, root: target.path) }
                            self.deleteIndex = 0; self.continueDeleting()
                            return
                        }
                        if directory.jobID == self.activeJob, self.activeDownloadSource?.directory == true {
                            self.downloadSize = directory.entries.reduce(0) { $0 + $1.size }
                        }
                        return
                    }
                    self.path = directory.path; self.entries = directory.entries
                    self.loading = false
                    if !self.transferring { self.status = "\(directory.entries.count) 个项目" }
                } catch is CancellationError {
                } catch {
                    guard !Task.isCancelled else { return }
                    if self?.deleting == true { self?.stopDeleting(); self?.lastDeleteError = error.localizedDescription }
                    self?.loading = false; self?.status = "目录数据格式无效，请刷新重试"
                }
            }
            return
        }
        if name == "job_error", integer(event["id"]) == 0, loading {
            directoryTask?.cancel(); directoryTask = nil
            loading = false; status = event["err"] as? String ?? "读取目录失败，请刷新重试"
            return
        }
        if let activeDeleteJob, integer(event["id"]) == activeDeleteJob {
            if name == "job_error" { stopDeleting(); lastDeleteError = event["err"] as? String ?? "删除失败"; status = lastDeleteError; load(path) }
            else if name == "job_done" {
                if removingEmptyDirectories { startNextDelete() }
                else if integer(event["file_num"]) == deleteIndex { deleteIndex += 1; continueDeleting() }
            }
            return
        }
        guard let activeJob, integer(event["id"]) == activeJob else { return }
        switch name {
        case "job_progress":
            let bytes = Int64(Double(event["finished_size"] as? String ?? "") ?? 0)
            if downloadTarget != nil { downloadFinished = bytes }
            status = "已传输 \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
        case "job_done":
            if waitingForEmptyFolders { folderTransferFinished = true; status = "正在保存空文件夹…" }
            else { finishDownloadJob() }
        case "job_error":
            emptyFolderTask?.cancel(); emptyFolderTask = nil; waitingForEmptyFolders = false; folderTransferFinished = false
            self.activeJob = nil; transferring = false; status = event["err"] as? String ?? "文件传输失败"; cleanupUpload()
        case "override_file_confirm": overwrite = NativeFileOverwrite(id: integer(event["id"]), file: integer(event["file_num"]), upload: event["is_upload"] as? String == "true")
        default: break
        }
    }
    private func finishDownloadJob() {
            if let target = downloadTarget {
                do { try FileManager.default.removeItem(at: target.deletingLastPathComponent().appendingPathComponent(".swiftrust-incomplete")) }
                catch { status = error.localizedDescription; transferring = false; self.activeJob = nil; return }
            }
            self.activeJob = nil; transferring = false; downloadedURL = downloadTarget; status = "传输完成"; cleanupUpload()
            Task { await reloadDownloads() }
            load(path)
            startNextDownload()
    }
    private func integer(_ value: Any?) -> Int { (value as? Int) ?? Int(value as? String ?? "") ?? 0 }
    private func cleanupUpload() {
        guard let folder = uploadDirectory else { return }
        do { try FileManager.default.removeItem(at: folder) }
        catch { NSLog("Temporary upload cleanup failed: %@", error.localizedDescription) }
        uploadDirectory = nil
    }
}

@available(iOS 17.0, *)
struct NativeFileScreen: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    var body: some View { NativeFileContent(model: model, files: model.fileBrowser) }
}

@available(iOS 17.0, *)
private enum NativeFileAlert: Identifiable {
    case deletion(NativeRemoteDeleteConfirmation)
    case overwrite(NativeFileOverwrite)
    var id: String {
        switch self {
        case .deletion(let request): return request.id.uuidString
        case .overwrite(let request): return "overwrite-\(request.id)-\(request.file)"
        }
    }
}

@available(iOS 17.0, *)
private struct NativeFileContent: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @ObservedObject var files: NativeFileModel
    @State private var importing = false
    @State private var selecting = false
    @State private var selected: Set<String> = []
    @State private var deleteConfirmation: NativeRemoteDeleteConfirmation?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(files.path.isEmpty ? NativeL("远程文件") : files.path).font(.subheadline.monospaced()).textSelection(.enabled)
                    }
                    HStack { if files.loading || files.transferring || files.deleting { ProgressView() }; Text(NativeL(model.connected ? files.status : model.status)).font(.caption).foregroundStyle(.secondary) }
                    if files.transferring { Button(NativeL("取消传输"), role: .cancel) { files.cancel() } }
                    if !files.lastDeleteError.isEmpty { Text(NativeL(files.lastDeleteError)).font(.caption).foregroundStyle(.red) }
                    if files.deleting { Button(NativeL("停止删除"), role: .cancel) { files.stopDeleting(); files.load(files.path) } }
                    if selecting {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NativeF("已选择 %@ 项", String(selected.count))).font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 16) {
                                Button { downloadSelection() } label: {
                                    Label(NativeL("下载"), systemImage: "arrow.down.circle").frame(maxWidth: .infinity, minHeight: 28)
                                }.tint(nativeRustBlue).disabled(selected.isEmpty || files.deleting).accessibilityLabel(NativeL("下载所选项目"))
                                Button(role: .destructive) { requestDelete(files.entries.filter { selected.contains($0.id) }) } label: {
                                    Label(NativeL("删除"), systemImage: "trash").frame(maxWidth: .infinity, minHeight: 28)
                                }.tint(.red).disabled(selected.isEmpty || files.loading || files.transferring || files.deleting).accessibilityLabel(NativeL("删除所选项目"))
                            }.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 12)).controlSize(.regular)
                        }.padding(.vertical, 4)
                    }
                }
                Section(NativeL("远程设备")) {
                    ForEach(files.entries) { file in
                        Button {
                            if selecting {
                                if selected.contains(file.id) { selected.remove(file.id) } else { selected.insert(file.id) }
                            } else if file.directory { files.load(files.child(file.name)) }
                            else { files.download(file, peer: model.remoteID ?? ""); model.sheet = .downloads }
                        } label: {
                            HStack(spacing: 12) {
                                if selecting { Image(systemName: selected.contains(file.id) ? "checkmark.circle.fill" : "circle") }
                                Image(systemName: file.directory ? "folder" : "doc").frame(width: 28)
                                Text(file.name).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                if file.directory { Image(systemName: "chevron.right") }
                                else { Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)).font(.caption).foregroundStyle(.secondary); Image(systemName: "arrow.down") }
                            }.padding(.vertical, 4)
                        }.disabled(files.loading || files.deleting || (files.transferring && !files.isDownloading))
                        .contextMenu {
                            Button { files.download(file, peer: model.remoteID ?? ""); model.sheet = .downloads } label: { Label(NativeL("下载"), systemImage: "arrow.down.circle") }
                            Button(role: .destructive) { requestDelete([file]) } label: { Label(NativeL("删除"), systemImage: "trash") }
                                .disabled(files.loading || files.transferring || files.deleting)
                        }
                    }
                    if files.entries.isEmpty && !files.loading && model.connected { Text(NativeL("此目录为空")).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(model.remoteName).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { if files.isDownloading { model.fileBrowserMinimized = true } else { Task { await model.send("disconnect") } } } label: { Image(systemName: "chevron.left") }.accessibilityLabel(NativeL(files.isDownloading ? "返回主页" : "断开文件连接")) }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { selecting.toggle(); selected = [] } label: { Image(systemName: selecting ? "checkmark.circle.fill" : "checkmark.circle") }.accessibilityLabel(NativeL("多选"))
                    Button { model.sheet = .downloads } label: { Image(systemName: "arrow.down.circle") }.accessibilityLabel(NativeL("下载管理"))
                    Button { files.load(files.path) } label: { Image(systemName: "arrow.clockwise") }.disabled(!model.connected || files.loading)
                    Button { files.parent() } label: { Image(systemName: "arrow.turn.up.left") }.disabled(files.loading || files.transferring || !model.connected).accessibilityLabel(NativeL("上一级目录"))
                    Button { importing = true } label: { Image(systemName: "tray.and.arrow.up") }.disabled(!model.connected || files.loading || files.transferring).accessibilityLabel(NativeL("上传文件"))
                }
            }
            .background(NativeUploadPresenter(isPresented: $importing) { files.upload($0) })
            .onChange(of: files.path) { _, _ in selected = [] }
            .alert(item: Binding<NativeFileAlert?>(get: {
                if let request = deleteConfirmation { return .deletion(request) }
                if let request = files.overwrite { return .overwrite(request) }
                return nil
            }, set: { _ in deleteConfirmation = nil; files.overwrite = nil })) { alert in
                switch alert {
                case .deletion(let request):
                    return Alert(title: Text(NativeF("永久删除 %@ 项？", String(request.targets.count))), message: Text(request.targets.map(\.path).prefix(5).joined(separator: "\n") + "\n\n" + NativeL("将永久删除远端文件和文件夹内全部内容，无法撤销。")),
                          primaryButton: .destructive(Text(NativeL("永久删除"))) { selected = []; selecting = false; files.delete(request) },
                          secondaryButton: .cancel(Text(NativeL("取消"))))
                case .overwrite(let request):
                    return Alert(title: Text(NativeL("替换远程同名文件？")),
                        primaryButton: .destructive(Text(NativeL("替换"))) { files.confirmOverwrite(request) },
                        secondaryButton: .cancel { files.cancel() })
                }
            }
        }.tint(.primary)
    }
    private func requestDelete(_ targets: [NativeRemoteFile]) {
        guard !targets.isEmpty, let session = model.currentSessionID else { return }
        deleteConfirmation = NativeRemoteDeleteConfirmation(targets: targets.map { NativeRemoteDeleteTarget(file: $0, path: files.child($0.name)) }, session: session)
    }
    private func downloadSelection() {
        files.download(files.entries.filter { selected.contains($0.id) }, peer: model.remoteID ?? "")
        selecting = false; selected = []; model.sheet = .downloads
    }
}


@available(iOS 17.0, *)
struct NativeUploadPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let selected: (URL) -> Void
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.requested = isPresented
        controller.completion = { url in isPresented = false; if let url { selected(url) } }
        DispatchQueue.main.async { controller.showIfNeeded() }
    }
    final class Controller: UIViewController, UIDocumentPickerDelegate {
        var requested = false
        var completion: ((URL?) -> Void)?
        private var picker: UIDocumentPickerViewController?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); showIfNeeded() }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); showIfNeeded() }
        func showIfNeeded() {
            guard requested, picker == nil, var presenter = viewIfLoaded?.window?.rootViewController else { return }
            while let presented = presenter.presentedViewController { presenter = presented }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
            picker.allowsMultipleSelection = false
            picker.delegate = self
            picker.modalPresentationStyle = .fullScreen
            self.picker = picker
            presenter.present(picker, animated: true)
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish(urls.first) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(nil) }
        private func finish(_ url: URL?) {
            requested = false
            picker?.dismiss(animated: true) { [weak self] in self?.picker = nil; self?.completion?(url) }
        }
    }
}


@available(iOS 17.0, *)
struct NativeDownloadsView: View {
    @ObservedObject var files: NativeFileModel
    @State private var selecting = false
    @State private var selected: Set<URL> = []
    @State private var pendingDeletion: Set<URL> = []
    @State private var confirmDeletion = false
    var body: some View {
        List {
            if files.isDownloading {
                Section(NativeL("正在下载")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(files.downloadName, systemImage: "arrow.down.circle").font(.headline)
                        ProgressView(value: Double(files.downloadFinished), total: Double(max(files.downloadSize, 1)))
                        HStack {
                            Text(NativeL(files.status)).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(NativeL("取消"), role: .cancel) { files.cancel() }
                        }
                    }.padding(.vertical, 6)
                }
            }
            if !files.pendingDownloads.isEmpty {
                Section(NativeL("等待下载")) {
                    ForEach(files.pendingDownloads) { request in Label(request.file.name, systemImage: request.file.directory ? "folder" : "doc") }
                    if !files.transferring { Button(NativeL("继续下载")) { files.startNextDownload() } }
                }
            }
            if !files.transferring, !files.downloadName.isEmpty {
                Section(NativeL("最近任务")) { Text(NativeL(files.status)).font(.subheadline).foregroundStyle(.secondary) }
            }
            if !files.localDownloadDeletionError.isEmpty {
                Section { Text(files.localDownloadDeletionError).font(.footnote).foregroundStyle(.red) }
            }
            Section(NativeL("已下载")) {
                ForEach(files.downloads) { file in
                    HStack(spacing: 12) {
                        if selecting { Image(systemName: selected.contains(file.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(nativeRustBlue) }
                        Image(systemName: file.directory ? "folder" : "doc").font(.title2).frame(width: 36)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(file.url.lastPathComponent).lineLimit(2)
                            Text(file.directory ? NativeL("文件夹") : ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if !selecting {
                            ShareLink(item: file.url) { Image(systemName: "square.and.arrow.up").frame(width: 40, height: 40) }
                                .buttonStyle(.bordered).accessibilityLabel(NativeL("分享文件"))
                        }
                    }.padding(.vertical, 4).contentShape(Rectangle())
                    .onTapGesture {
                        if selecting {
                            if selected.contains(file.id) { selected.remove(file.id) } else { selected.insert(file.id) }
                        }
                    }.disabled(files.deletingLocalDownloads)
                    .swipeActions {
                        if !selecting && !files.deletingLocalDownloads { Button(NativeL("删除"), role: .destructive) { files.deleteDownload(file) } }
                    }
                }
                if files.downloads.isEmpty { Text(NativeL("暂无已下载文件")).foregroundStyle(.secondary) }
            }
            Section {
                Text(NativeL("文件保存在本机 SwiftRust 的 Downloads 文件夹。返回浏览页面不会停止下载；断开连接会取消任务。系统后台可执行时间由 iOS 决定。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(NativeL("下载管理")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NativeL(selecting ? "取消多选" : "多选")) { selecting.toggle(); selected = [] }
                        .disabled(files.downloads.isEmpty || files.deletingLocalDownloads)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selecting {
                    HStack(spacing: 16) {
                        Text(NativeF("已选择 %@ 项", String(selected.count))).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) { pendingDeletion = selected; confirmDeletion = true } label: {
                            Label(NativeL("删除"), systemImage: "trash").frame(minWidth: 84, minHeight: 28)
                        }.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 12)).tint(.red)
                            .disabled(selected.isEmpty || files.deletingLocalDownloads)
                        if files.deletingLocalDownloads { ProgressView() }
                    }.padding(16).background(.regularMaterial)
                }
            }
            .alert(NativeF("删除 %@ 项本机下载？", String(pendingDeletion.count)), isPresented: $confirmDeletion) {
                Button(NativeL("删除"), role: .destructive) {
                    Task { await files.deleteDownloads(pendingDeletion); selected = []; selecting = false }
                }
                Button(NativeL("取消"), role: .cancel) {}
            } message: { Text(NativeL("将删除选中的本机下载副本，无法撤销。")) }
            .task { await files.reloadDownloads() }
            .onChange(of: files.downloads.map(\.id)) { _, ids in selected.formIntersection(ids) }
    }
}
