// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

enum NativeTerminalKeys {
    static let shortcuts: [NativeShortcut] = [
        .init(title: "中断", key: "VK_C", modifiers: ["ctrl"]),
        .init(title: "结束输入", key: "VK_D", modifiers: ["ctrl"]),
        .init(title: "挂起", key: "VK_Z", modifiers: ["ctrl"]),
        .init(title: "清屏", key: "VK_L", modifiers: ["ctrl"]),
        .init(title: "搜索历史", key: "VK_R", modifiers: ["ctrl"]),
        .init(title: "行首", key: "VK_A", modifiers: ["ctrl"]),
        .init(title: "行尾", key: "VK_E", modifiers: ["ctrl"]),
        .init(title: "删除至行首", key: "VK_U", modifiers: ["ctrl"]),
        .init(title: "删除至行尾", key: "VK_K", modifiers: ["ctrl"]),
        .init(title: "退出", key: "VK_ESCAPE"),
        .init(title: "制表", key: "VK_TAB"),
        .init(title: "粘贴", key: "VK_V", modifiers: ["command"])
    ]
    static func isLocalCommand(_ key: String, modifiers: Set<String>) -> Bool {
        modifiers.contains("command") && modifiers.isSubset(of: ["command", "shift"]) && ["VK_C", "VK_V", "VK_A"].contains(key)
    }
    static func text(_ value: String, modifiers: Set<String>) -> String? {
        guard !modifiers.contains("command") else { return nil }
        var result = value
        if modifiers.contains("ctrl") {
            guard value.unicodeScalars.count == 1, value.unicodeScalars.allSatisfy({ $0.isASCII }), let scalar = value.uppercased().unicodeScalars.first else { return nil }
            if value == " " || value == "@" { result = "\0" }
            else if scalar.value >= 64 && scalar.value <= 95 { result = String(UnicodeScalar(UInt8(scalar.value & 31))) }
            else if value == "?" { result = "\u{7f}" }
            else { return nil }
        }
        return modifiers.contains("alt") ? "\u{1b}" + result : result
    }
    static func sequence(_ key: String, modifiers: Set<String>, applicationCursor: Bool = false) -> String? {
        guard !modifiers.contains("command") else { return nil }
        let shift = modifiers.contains("shift")
        let parameter = 1 + (shift ? 1 : 0) + (modifiers.contains("alt") ? 2 : 0) + (modifiers.contains("ctrl") ? 4 : 0)
        if let end = ["VK_UP":"A", "VK_DOWN":"B", "VK_RIGHT":"C", "VK_LEFT":"D", "VK_HOME":"H", "VK_END":"F"][key] {
            if parameter > 1 { return "\u{1b}[1;\(parameter)\(end)" }
            return "\u{1b}" + (applicationCursor ? "O" : "[") + end
        }
        if let number = ["VK_INSERT":2, "VK_DELETE":3, "VK_PRIOR":5, "VK_NEXT":6, "VK_F5":15, "VK_F6":17, "VK_F7":18, "VK_F8":19, "VK_F9":20, "VK_F10":21, "VK_F11":23, "VK_F12":24][key] {
            return "\u{1b}[\(number)" + (parameter > 1 ? ";\(parameter)" : "") + "~"
        }
        if let end = ["VK_F1":"P", "VK_F2":"Q", "VK_F3":"R", "VK_F4":"S"][key] {
            return parameter > 1 ? "\u{1b}[1;\(parameter)\(end)" : "\u{1b}O\(end)"
        }
        switch key {
        case "VK_ESCAPE": return "\u{1b}"
        case "VK_TAB": return shift ? "\u{1b}[Z" : (modifiers.contains("alt") ? "\u{1b}\t" : "\t")
        case "VK_RETURN": return modifiers.contains("alt") ? "\u{1b}\r" : "\r"
        case "VK_BACK": return modifiers.contains("alt") ? "\u{1b}\u{7f}" : "\u{7f}"
        case "VK_SPACE": return text(" ", modifiers: modifiers)
        default: break
        }
        let pairs = ["VK_MINUS":("-","_"), "VK_EQUALS":("=","+"), "VK_COMMA":(",","<"), "VK_PERIOD":(".",">"), "VK_SLASH":("/","?")]
        if let pair = pairs[key] { return text(shift ? pair.1 : pair.0, modifiers: modifiers) }
        let character = key.replacingOccurrences(of: "VK_", with: "")
        guard character.count == 1, character.unicodeScalars.allSatisfy({ $0.isASCII }) else { return nil }
        if let index = "1234567890".firstIndex(of: Character(character)), shift {
            let offset = "1234567890".distance(from: "1234567890".startIndex, to: index)
            return text(String(Array("!@#$%^&*()")[offset]), modifiers: modifiers)
        }
        return text(shift ? character.uppercased() : character.lowercased(), modifiers: modifiers)
    }
}
