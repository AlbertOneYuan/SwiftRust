// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit

struct NativeQuickDevice: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var mode: String = "desktop"
    var relay = false
    var menuID: String { mode + "." + id }
    var modeTitle: String {
        switch mode {
        case "terminal": return NativeL("终端")
        case "files": return NativeL("传输文件")
        case "camera": return NativeL("查看摄像头")
        default: return NativeL("远程控制")
        }
    }
    var link: NativeLaunchLink {
        var link = NativeLaunchLink(id: id, mode: NativeSessionKind(rawValue: mode) ?? .desktop)
        link.relay = relay; link.newWindow = true
        return link
    }
}

@available(iOS 17.0, *)
@MainActor final class NativeQuickDevices: ObservableObject {
    static let shared = NativeQuickDevices()
    static let storageKey = "native.home-quick-devices"
    @Published private(set) var devices: [NativeQuickDevice] = []
    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey), let saved = try? JSONDecoder().decode([NativeQuickDevice].self, from: data) { devices = saved }
    }
    func save(_ value: [NativeQuickDevice]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        devices = value
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        NativeHomeQuickActions.refresh()
    }
    func select(_ peer: NativePeer, mode: String, enabled: Bool) {
        var value = devices.filter { $0.id != peer.id || $0.mode != mode }
        if enabled { value.append(NativeQuickDevice(id: peer.id, name: peer.name, mode: mode, relay: peer.forceRelay)) }
        save(value)
    }
    func relay(_ menuID: String, value: Bool) {
        var selected = devices
        if let index = selected.firstIndex(where: { $0.menuID == menuID }) { selected[index].relay = value; save(selected) }
    }
}

@available(iOS 17.0, *)
@MainActor enum NativeHomeQuickActions {
    static let newWindow = "me.airefactor.swiftrust.home.window"
    static let scan = "me.airefactor.swiftrust.home.scan"
    static let configure = "me.airefactor.swiftrust.home.configure"
    static let common = "me.airefactor.swiftrust.home.common"
    static func deviceAction(_ device: NativeQuickDevice) -> String { common + "." + device.menuID }
    static func items(devices: [NativeQuickDevice]) -> [UIApplicationShortcutItem] {
        let deviceItems = devices.map { device in
            UIApplicationShortcutItem(type: deviceAction(device), localizedTitle: device.name, localizedSubtitle: device.modeTitle + " · " + device.id, icon: UIApplicationShortcutIcon(systemImageName: "display"))
        }
        let items = [
            UIApplicationShortcutItem(type: newWindow, localizedTitle: NativeL("添加窗口"), localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "macwindow.badge.plus")),
            UIApplicationShortcutItem(type: scan, localizedTitle: NativeL("扫码连接"), localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "qrcode.viewfinder")),
            UIApplicationShortcutItem(type: configure, localizedTitle: NativeL("桌面菜单设备"), localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "star.circle"))
        ]
        return deviceItems + items
    }

    static func refresh() { UIApplication.shared.shortcutItems = items(devices: NativeQuickDevices.shared.devices) }
    @discardableResult static func perform(_ type: String, model: NativeShellModel, inNewScene: Bool) async -> Bool {
        model.cancelBackgroundRecovery()
        switch type {
        case newWindow:
            guard UIApplication.shared.supportsMultipleScenes else { model.errorMessage = "当前系统不支持同时打开多个窗口"; return true }
            if inNewScene { model.selected = .connection }
            else { NativeWindowLaunch.open(nil) { model.errorMessage = $0 } }
        case scan:
            if model.remoteID != nil {
                NativeWindowLaunch.open(nil, action: "scan") { model.errorMessage = $0 }
            } else { model.sheet = .scanner }
        case configure: model.sheet = .quickDeviceSettings
        default:
            guard let device = NativeQuickDevices.shared.devices.first(where: { deviceAction($0) == type }) else { return false }
            await connect(device, model: model, inNewScene: inNewScene)
        }
        return true
    }
    static func connect(_ device: NativeQuickDevice, model: NativeShellModel, inNewScene: Bool = false) async {
        var link = device.link
        if !UIApplication.shared.supportsMultipleScenes { link.newWindow = false }
        await model.openLaunchLink(link, inNewScene: inNewScene)
    }
}

@available(iOS 17.0, *)
struct NativeQuickDeviceSettings: View {
    @ObservedObject var model: NativeShellModel
    @ObservedObject private var store = NativeQuickDevices.shared
    var body: some View {
        Form {
            Section {
                ForEach(store.devices, id: \.menuID) { device in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(device.name).font(.headline); Spacer(); Button(role: .destructive) { store.save(store.devices.filter { $0.menuID != device.menuID }) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel(NativeF("移除桌面菜单设备：%@", device.name)) }
                        Text(device.id).font(.footnote.monospaced()).foregroundStyle(.secondary)
                        Text(device.modeTitle).foregroundStyle(.secondary)
                        Toggle(NativeL("强制中继连接"), isOn: Binding(get: { device.relay }, set: { store.relay(device.menuID, value: $0) })).tint(.green)
                    }
                }
                if store.devices.isEmpty { Text(NativeL("从下方最近连接中选择设备及连接方式。")) }
            } header: { Text(NativeL("桌面菜单设备")) } footer: {
                Text(NativeL("桌面长按菜单优先显示已选入口，同一设备可添加多种连接方式，点击后直接在新窗口连接。显示数量由系统决定；系统不支持多窗口时，仅在空闲窗口连接，不会替换已有连接。"))
            }
            Section(NativeL("最近连接")) {
                ForEach(model.peers) { peer in
                    DisclosureGroup {
                        ForEach(["desktop", "terminal", "files", "camera"], id: \.self) { mode in
                            Toggle(NativeQuickDevice(id: peer.id, name: peer.name, mode: mode).modeTitle,
                                   isOn: Binding(get: { store.devices.contains { $0.id == peer.id && $0.mode == mode } }, set: { store.select(peer, mode: mode, enabled: $0) })).tint(.green)
                        }
                    } label: {
                        HStack { NativePeerBadge(peer: peer); VStack(alignment: .leading) { Text(peer.name); Text(peer.id).font(.footnote.monospaced()).foregroundStyle(.secondary) } }
                    }
                }
                if model.peers.isEmpty { Text(NativeL("先连接一台设备，连接记录会显示在这里。")) }
            }
        }.navigationTitle(NativeL("桌面菜单设备")).navigationBarTitleDisplayMode(.inline)
    }
}
