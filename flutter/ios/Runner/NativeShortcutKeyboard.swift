// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit

let nativeKeyboardBackgroundColor = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
}
private let nativeKeyboardSurface = Color(uiColor: nativeKeyboardBackgroundColor)
private let nativeKeyboardKey = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0.36, alpha: 1) : .white
})

struct NativeShortcut: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var key: String
    var modifiers: Set<String> = []

    var combination: String {
        let prefix = [("ctrl", "⌃"), ("alt", "⌥"), ("shift", "⇧"), ("command", "⌘")]
            .filter { modifiers.contains($0.0) }.map(\.1).joined()
        return prefix + NativeShortcutKeys.label(for: key)
    }
    var arguments: [String: Any] {
        var result: [String: Any] = ["value": key]
        for flag in ["ctrl", "alt", "shift", "command"] where modifiers.contains(flag) { result[flag] = true }
        return result
    }
    static let defaults: [NativeShortcut] = [
        .init(title: "复制", key: "VK_C", modifiers: ["command"]),
        .init(title: "粘贴", key: "VK_V", modifiers: ["command"]),
        .init(title: "剪切", key: "VK_X", modifiers: ["command"]),
        .init(title: "撤销", key: "VK_Z", modifiers: ["command"]),
        .init(title: "全选", key: "VK_A", modifiers: ["command"]),
        .init(title: "保存", key: "VK_S", modifiers: ["command"]),
        .init(title: "查找", key: "VK_F", modifiers: ["command"]),
        .init(title: "切换窗口", key: "VK_TAB", modifiers: ["alt"]),
        .init(title: "中断", key: "VK_C", modifiers: ["ctrl"]),
        .init(title: "结束输入", key: "VK_D", modifiers: ["ctrl"]),
        .init(title: "退出", key: "VK_ESCAPE"),
        .init(title: "制表", key: "VK_TAB")
    ]
}

enum NativeShortcutKeys {
    static let groups: [(String, [String])] = [
        ("字母", Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { "VK_\($0)" }),
        ("数字", Array("1234567890").map { "VK_\($0)" }),
        ("功能键", (1...12).map { "VK_F\($0)" }),
        ("符号", ["VK_MINUS", "VK_EQUALS", "VK_COMMA", "VK_PERIOD", "VK_SLASH"]),
        ("导航与编辑", ["VK_ESCAPE", "VK_TAB", "VK_RETURN", "VK_SPACE", "VK_BACK", "VK_DELETE", "VK_INSERT", "VK_HOME", "VK_END", "VK_PRIOR", "VK_NEXT", "VK_LEFT", "VK_UP", "VK_DOWN", "VK_RIGHT"])
    ]
    static func label(for key: String) -> String {
        let names = ["VK_MINUS": "-", "VK_EQUALS": "=", "VK_COMMA": ",", "VK_PERIOD": ".", "VK_SLASH": "/", "VK_ESCAPE": "Esc", "VK_RETURN": "↵", "VK_SPACE": "Space", "VK_BACK": "⌫", "VK_DELETE": "Del", "VK_INSERT": "Ins", "VK_PRIOR": "PgUp", "VK_NEXT": "PgDn", "VK_LEFT": "←", "VK_UP": "↑", "VK_DOWN": "↓", "VK_RIGHT": "→", "VK_TAB": "Tab", "VK_HOME": "Home", "VK_END": "End"]
        return names[key] ?? key.replacingOccurrences(of: "VK_", with: "")
    }
}

@MainActor
final class NativeShortcutLibrary: ObservableObject {
    @Published private(set) var items: [NativeShortcut]
    @Published var error: String?
    private let defaults: UserDefaults
    private let storageKey = "native.keyboard.custom-shortcuts"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey) {
            do { items = try JSONDecoder().decode([NativeShortcut].self, from: data) }
            catch { items = []; self.error = "无法读取自定义快捷键：\(error.localizedDescription)" }
        } else { items = NativeShortcut.defaults }
    }
    func save(_ item: NativeShortcut) {
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item }
        else { items.append(item) }
        persist()
    }
    func delete(at offsets: IndexSet) { items.remove(atOffsets: offsets); persist() }
    func move(from offsets: IndexSet, to destination: Int) { items.move(fromOffsets: offsets, toOffset: destination); persist() }
    func restoreDefaults() { items = NativeShortcut.defaults; persist() }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(items), forKey: storageKey) }
        catch { self.error = "无法保存快捷键：\(error.localizedDescription)" }
    }
}

@available(iOS 17.0, *)
struct NativeShortcutSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var library: NativeShortcutLibrary
    @State private var editing: NativeShortcut?
    @State private var editMode = EditMode.inactive
    @State private var confirmReset = false
    @AppStorage("native.keyboard.haptics") private var haptics = true
    var body: some View {
        List {
            Section(NativeL("快捷键盘")) {
                Toggle(NativeL("按键震动"), isOn: $haptics).tint(.green)
                    .accessibilityIdentifier("native.keyboardHaptics")
            }
            Section {
                ForEach(library.items) { shortcut in
                    Button { editing = shortcut } label: {
                        HStack {
                            Text(shortcut.title).foregroundStyle(.primary)
                            Spacer()
                            Text(shortcut.combination).font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("native.shortcut.\(shortcut.id)")
                }
                .onDelete(perform: library.delete)
                .onMove(perform: library.move)
                if library.items.isEmpty { Text(NativeL("点右上角添加快捷键")).foregroundStyle(.secondary) }
            } footer: { Text(NativeL("轻点编辑，左滑删除；排序后会同步到快捷键盘的常用页。组合键仅在点按时发送。")) }
            Section {
                Text(NativeL("默认组合键使用 Command，适合 Mac；连接 Windows 或 Linux 时可改为 Ctrl。")).font(.footnote).foregroundStyle(.secondary)
                Button(NativeL("恢复默认快捷键"), role: .destructive) { confirmReset = true }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(NativeL("自定义快捷键")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode == .active ? NativeL("完成") : NativeL("排序")) { editMode = editMode == .active ? .inactive : .active }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = NativeShortcut(title: "", key: "VK_C", modifiers: ["command"]) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(NativeL("添加快捷键"))
            }
        }
        .sheet(item: $editing) { shortcut in
            NavigationStack { NativeShortcutEditor(shortcut: shortcut, save: library.save) }
        }
        .alert(NativeL("恢复默认快捷键？"), isPresented: $confirmReset) {
            Button(NativeL("取消"), role: .cancel) {}
            Button(NativeL("恢复默认"), role: .destructive) { library.restoreDefaults() }
        } message: { Text(NativeL("将替换当前自定义列表。")) }
        .alert(NativeL("快捷键"), isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button(NativeL("好")) { library.error = nil }
        } message: { Text(NativeL(library.error ?? "")) }
    }
}

@available(iOS 17.0, *)
private struct NativeShortcutEditor: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @Environment(\.dismiss) private var dismiss
    @State var shortcut: NativeShortcut
    let save: (NativeShortcut) -> Void
    var body: some View {
        Form {
            Section(NativeL("名称")) { TextField(NativeL("例如：复制"), text: $shortcut.title).accessibilityIdentifier("native.shortcutName") }
            Section(NativeL("组合键")) {
                ForEach([("ctrl", "Control"), ("alt", "Alt / Option"), ("shift", "Shift"), ("command", "Command / Windows")], id: \.0) { flag in
                    Toggle(flag.1, isOn: Binding(get: { shortcut.modifiers.contains(flag.0) }, set: { value in
                        if value { shortcut.modifiers.insert(flag.0) } else { shortcut.modifiers.remove(flag.0) }
                    })).tint(.green)
                }
                Picker(NativeL("按键"), selection: $shortcut.key) {
                    ForEach(NativeShortcutKeys.groups, id: \.0) { group in
                        Section(group.0) {
                            ForEach(group.1, id: \.self) { key in Text(NativeShortcutKeys.label(for: key)).tag(key) }
                        }
                    }
                }
            }
            Section(NativeL("预览")) { Text(shortcut.combination).font(.system(.title2, design: .monospaced)).frame(maxWidth: .infinity) }
        }
        .navigationTitle(NativeL("编辑快捷键")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(NativeL("取消")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(NativeL("保存")) {
                    shortcut.title = shortcut.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    save(shortcut); dismiss()
                }.disabled(shortcut.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

@available(iOS 17.0, *)
struct NativeRemoteKeyboard: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @ObservedObject var library: NativeShortcutLibrary
    @Binding var visible: Bool
    var compact: Bool
    var terminal: NativeTerminalModel?
    @AppStorage("native.keyboard.haptics") private var haptics = true
    @State private var page = Page.shortcuts
    @State private var modifiers: Set<String> = []
    private enum Page: Int, CaseIterable {
        case shortcuts, letters, symbols, function
        var title: String { [NativeL("常用"), NativeL("字母"), NativeL("符号"), NativeL("功能")][rawValue] }
    }
    init(model: NativeShellModel, visible: Binding<Bool>, compact: Bool = false, terminal: NativeTerminalModel? = nil) {
        self.model = model; library = model.shortcuts; _visible = visible; self.compact = compact; self.terminal = terminal
    }
    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            HStack(spacing: 8) {
                ForEach(Page.allCases, id: \.self) { tab in
                    Button { page = tab } label: {
                        Text(tab.title).font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: compact ? 26 : 30)
                            .foregroundStyle(page == tab ? Color.white : Color.primary)
                            .background(page == tab ? nativeRustBlue : nativeKeyboardKey, in: RoundedRectangle(cornerRadius: 7))
                    }.accessibilityIdentifier("native.keyboardPage.\(tab.rawValue)")
                        .accessibilityAddTraits(page == tab ? .isSelected : [])
                }
                Button { if let terminal { terminal.view?.showSystemKeyboard() } else { model.canvas?.showSystemKeyboard() } } label: { Image(systemName: "keyboard").frame(width: 34, height: compact ? 26 : 30).background(nativeKeyboardKey, in: RoundedRectangle(cornerRadius: 7)) }
                    .accessibilityLabel(NativeL("系统键盘"))
                Button { visible = false; if let terminal { _ = terminal.view?.resignFirstResponder() } else { model.canvas?.hideSystemKeyboard() } } label: { Image(systemName: "keyboard.chevron.compact.down").frame(width: 34, height: compact ? 26 : 30).background(nativeKeyboardKey, in: RoundedRectangle(cornerRadius: 7)) }
                    .accessibilityLabel(terminal == nil ? NativeL("收起远程键盘") : NativeL("收起终端键盘"))
            }.id(page)
            TabView(selection: $page) {
                shortcutPage.tag(Page.shortcuts)
                letters.tag(Page.letters)
                symbols.tag(Page.symbols)
                functionKeys.tag(Page.function)
            }.tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.top, compact ? 10 : 18).padding(.horizontal, 12).padding(.bottom, compact ? 8 : 12).buttonStyle(.plain)
        .foregroundStyle(.primary).background(nativeKeyboardSurface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .accessibilityElement(children: .contain).accessibilityIdentifier("native.remoteKeyboard")
    }
    private var letters: some View {
        VStack(spacing: compact ? 4 : 8) {
            row(Array("QWERTYUIOP").map(String.init))
            row(Array("ASDFGHJKL").map(String.init)).padding(.horizontal, 8)
            HStack(spacing: 8) {
                modifier("⇧", "shift")
                ForEach(Array("ZXCVBNM").map(String.init), id: \.self) { key($0, "VK_\($0)") }
                key("⌫", "VK_BACK")
            }
            HStack(spacing: 8) {
                modifier("Ctrl", "ctrl"); modifier("Alt", "alt"); modifier("⌘", "command")
                key("空格", "VK_SPACE")
                key("↵", "VK_RETURN")
            }
        }.padding(.horizontal, 1)
    }
    private var symbols: some View {
        VStack(spacing: compact ? 4 : 8) {
            row(Array("1234567890").map(String.init))
            symbolRow(["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"])
            symbolRow(["[", "]", "{", "}", "<", ">", "=", "+", "-", "_"])
            HStack(spacing: 8) {
                ForEach(["/", "\\", ":", ";", "\"", "'", ",", ".", "?"], id: \.self) { textKey($0) }
                key("⌫", "VK_BACK")
            }
        }
    }
    private var functionKeys: some View {
        VStack(spacing: compact ? 4 : 8) {
            HStack(spacing: 8) {
                ForEach(1...6, id: \.self) { n in key("F\(n)", "VK_F\(n)") }
                key("Esc", "VK_ESCAPE"); key("Tab", "VK_TAB")
            }
            HStack(spacing: 8) {
                ForEach(7...12, id: \.self) { n in key("F\(n)", "VK_F\(n)") }
                key("Ins", "VK_INSERT"); key("Del", "VK_DELETE")
            }
            HStack(spacing: 8) { key("Home", "VK_HOME"); key("End", "VK_END"); key("PgUp", "VK_PRIOR"); key("PgDn", "VK_NEXT"); key("←", "VK_LEFT"); key("↑", "VK_UP"); key("↓", "VK_DOWN"); key("→", "VK_RIGHT") }
            HStack(spacing: 8) { modifier("Ctrl", "ctrl"); modifier("Alt", "alt"); modifier("⇧", "shift"); modifier("⌘", "command"); key("⌫", "VK_BACK"); key("空格", "VK_SPACE"); key("↵", "VK_RETURN") }
        }
    }
    private var panelShortcuts: [NativeShortcut] {
        guard terminal != nil else { return library.items }
        let custom = library.items.filter { item in !NativeShortcut.defaults.contains { $0.title == item.title && $0.key == item.key && $0.modifiers == item.modifiers } }
        return NativeTerminalKeys.shortcuts + custom
    }
    private func sendKey(_ key: String, flags: Set<String>) {
        if let terminal { terminal.shortcut(key, modifiers: flags) }
        else {
            var args: [String: Any] = ["value": key]
            for modifier in ["ctrl", "alt", "shift", "command"] where flags.contains(modifier) { args[modifier] = true }
            Task { await model.send("key", arguments: args) }
        }
    }
    private func supportsKey(_ key: String, flags: Set<String>) -> Bool {
        terminal == nil || NativeTerminalKeys.isLocalCommand(key, modifiers: flags) || NativeTerminalKeys.sequence(key, modifiers: flags) != nil
    }
    private var shortcutPage: some View {
        GeometryReader { geometry in
            let columns = max(3, Int(geometry.size.width / 125))
            let rows = max(1, (panelShortcuts.count + columns - 1) / columns)
            let cellHeight = max(40, (geometry.size.height - CGFloat(rows - 1) * 8) / CGFloat(rows))
            if panelShortcuts.isEmpty {
                ContentUnavailableView(NativeL("暂无快捷键"), systemImage: "command", description: Text(NativeL("可在设置 → 自定义快捷键中添加")))
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                        ForEach(panelShortcuts) { shortcut in
                            Button { feedback(); modifiers.removeAll(); sendKey(shortcut.key, flags: shortcut.modifiers) } label: {
                                VStack(spacing: 3) {
                                    Text(terminal != nil && NativeTerminalKeys.shortcuts.contains(where: { $0.id == shortcut.id }) ? NativeL(shortcut.title) : shortcut.title).font(.system(size: compact ? 15 : 17, weight: .medium)).lineLimit(1)
                                    Text(shortcut.combination).font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: cellHeight)
                                .background(nativeKeyboardKey, in: RoundedRectangle(cornerRadius: 8))
                            }.disabled(!supportsKey(shortcut.key, flags: shortcut.modifiers))
                        }
                    }
                }
            }
        }
    }
    private func row(_ values: [String]) -> some View {
        HStack(spacing: 8) { ForEach(values, id: \.self) { key($0, "VK_\($0)") } }
    }
    private func symbolRow(_ values: [String]) -> some View {
        HStack(spacing: 8) { ForEach(values, id: \.self) { textKey($0) } }
    }
    private func textKey(_ value: String) -> some View {
        tile(value) {
            let flags = modifiers; modifiers.removeAll()
            if let terminal, let sequence = NativeTerminalKeys.text(value, modifiers: flags) { terminal.input(sequence) }
            else if terminal == nil { Task { await model.send("text", arguments: ["value": value]) } }
        }
    }
    private func key(_ label: String, _ value: String) -> some View {
        tile(label) { let flags = modifiers; modifiers.removeAll(); sendKey(value, flags: flags) }
            .disabled(!supportsKey(value, flags: modifiers))
            .accessibilityLabel(label == "⌫" ? NativeL("退格") : label == "↵" ? NativeL("回车") : label)
    }
    private func modifier(_ label: String, _ flag: String) -> some View {
        tile(label, selected: modifiers.contains(flag)) {
            if modifiers.contains(flag) { modifiers.remove(flag) } else { modifiers.insert(flag) }
        }.accessibilityAddTraits(modifiers.contains(flag) ? .isSelected : [])
    }
    private static let keySymbols = [
        "⌫": "delete.left", "↵": "return", "⇧": "shift", "⌘": "command",
        "←": "arrow.left", "↑": "arrow.up", "↓": "arrow.down", "→": "arrow.right",
        "Home": "arrow.up.to.line", "End": "arrow.down.to.line",
        "PgUp": "arrow.up.square", "PgDn": "arrow.down.square",
        "Esc": "escape", "Tab": "arrow.right.to.line", "Ctrl": "control", "Alt": "option",
        "Ins": "plus.square", "Del": "delete.right", "空格": "space"
    ]
    private func feedback() {
        if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
    private func tile(_ label: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button { feedback(); action() } label: {
            Group {
                if let symbol = Self.keySymbols[label] {
                    Image(systemName: symbol).font(.system(size: compact ? 19 : 23, weight: .medium))
                } else {
                    Text(NativeL(label)).font(.system(size: compact ? 16 : 20, weight: .medium, design: .monospaced))
                        .lineLimit(1).minimumScaleFactor(0.55)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.green : nativeKeyboardKey, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.accessibilityLabel(NativeL(label))
    }
}
