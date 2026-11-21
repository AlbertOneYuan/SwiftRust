// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit

private let nativeSwitchTint = Color.green
private var nativeRepositoryURL: URL? {
    guard let text = Bundle.main.object(forInfoDictionaryKey: "SwiftRustRepositoryURL") as? String,
          let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
    return url
}

enum NativeContact {
    static let feedback = URL(string: "mailto:airefactorme@icloud.com?subject=SwiftRust%20Feedback")!
    static let social = URL(string: "https://x.com/kiwicatone")!
    static var review: URL? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "SwiftRustAppStoreID") as? String,
              !id.isEmpty, id.allSatisfy({ $0.isNumber }) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }
}

enum NativeSettingsRoute: Hashable {
    case shortcuts, pointer, scroll, quickDevices, urlScheme, disconnect, prompts, tailscale, advanced, language, appIcon, peerAppearance, privacy, openSource, support
}

@available(iOS 17.0, *)
struct NativeSettingsView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @Binding var appearance: String
    var aboutRequest: Int = 0
    @AppStorage("native-show-home-login") private var showHomeLogin = true
    @AppStorage("native.skip-disconnect-confirmation") private var skipDisconnectConfirmation = false
    @AppStorage("native.launch-restore") private var launchRestore = false
    @AppStorage("native.foreground-reconnect") private var foregroundReconnect = false
    @AppStorage("native.background-disconnect-delay") private var backgroundDisconnectDelay = -1
    @AppStorage("native.default-canvas-lock") private var defaultCanvasLock = false

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section(NativeL("账号")) {
                Button { model.sheet = .account } label: {
                    Label(model.accountName.isEmpty ? NativeL("登录账号") : model.accountName, systemImage: "person.crop.circle")
                }.accessibilityIdentifier("native.settingsLogin")
                Toggle(NativeL("显示主页登录按钮"), isOn: $showHomeLogin).tint(nativeSwitchTint)
                    .accessibilityIdentifier("native.showHomeLogin")
            }
            Section {
                Picker(selection: Binding(get: { model.inputMode }, set: model.setMode)) {
                    Text(NativeL("触控板")).tag("trackpad")
                    Text(NativeL("新直接触控")).tag("touch-new")
                    Text(NativeL("鼠标")).tag("mouse")
                    Text(NativeL("直接触控")).tag("touch")
                } label: { Label(NativeL("输入模式"), systemImage: "hand.draw") }
                Button { model.sheet = .gestures } label: {
                    Label(NativeL("手势说明"), systemImage: "hand.point.up.left")
                }
                NavigationLink(value: NativeSettingsRoute.shortcuts) {
                    Label(NativeL("自定义快捷键"), systemImage: "command.square")
                }.accessibilityIdentifier("native.customShortcuts")
                NavigationLink(value: NativeSettingsRoute.pointer) {
                    LabeledContent { Text(NativeF("%@ 点", String(describing: Int(model.cursorSize)))) } label: { Label(NativeL("鼠标指针"), systemImage: "cursorarrow") }
                }

                NavigationLink(value: NativeSettingsRoute.scroll) {
                    Label(NativeL("滚动速度"), systemImage: "arrow.up.and.down")
                }.accessibilityIdentifier("native.scrollSettings")
                Toggle(isOn: $defaultCanvasLock) { Label(NativeL("默认锁定画布"), systemImage: "lock") }
                    .tint(.green).accessibilityIdentifier("native.defaultCanvasLock")
            } header: { Text(NativeL("操作")) }
            Section(NativeL("连接")) {
                Button { model.sheet = .downloads } label: { Label(NativeL("下载管理"), systemImage: "arrow.down.circle") }
                NavigationLink(value: NativeSettingsRoute.quickDevices) { Label(NativeL("桌面菜单设备"), systemImage: "star.circle") }
                    .accessibilityIdentifier("native.quickDeviceSettings")
                NavigationLink(value: NativeSettingsRoute.urlScheme) { Label(NativeL("URL Scheme 与桌面快捷启动"), systemImage: "link") }
                    .accessibilityIdentifier("native.urlSchemeHelp")
                if UIApplication.shared.supportsMultipleScenes {
                    Button { NativeWindowLaunch.open(nil) { model.errorMessage = $0 } } label: { Label(NativeL("新建窗口"), systemImage: "macwindow.badge.plus") }
                }
                Toggle(isOn: $launchRestore) { Label(NativeL("打开 App 时恢复上次会话"), systemImage: "arrow.uturn.forward") }
                    .tint(nativeSwitchTint).accessibilityIdentifier("native.launchRestore")
                Toggle(isOn: $foregroundReconnect) { Label(NativeL("从后台返回时自动重连"), systemImage: "arrow.clockwise") }
                    .tint(nativeSwitchTint).accessibilityIdentifier("native.foregroundReconnect")
                NavigationLink(value: NativeSettingsRoute.disconnect) { Label(NativeL("断开设置"), systemImage: "rectangle.portrait.and.arrow.right") }
                    .accessibilityIdentifier("native.disconnectSettings")
                Button { model.sheet = .servers } label: {
                    Label(NativeL("ID / 中继服务器"), systemImage: "server.rack")
                }
                Toggle(isOn: $model.forceRelay) { Label(NativeL("始终使用中继"), systemImage: "network") }.tint(nativeSwitchTint)
                NavigationLink(value: NativeSettingsRoute.prompts) { Label(NativeL("连接提示"), systemImage: "checkmark.bubble") }
                NavigationLink(value: NativeSettingsRoute.tailscale) {
                    Label("Tailscale", systemImage: "point.3.connected.trianglepath.dotted")
                }.accessibilityIdentifier("native.tailscaleSettings")
                NavigationLink(value: NativeSettingsRoute.advanced) {
                    Label(NativeL("高级设置"), systemImage: "slider.horizontal.3")
                }
            }
            Section {
                NavigationLink(value: NativeSettingsRoute.language) {
                    Label(NativeL("语言"), systemImage: "globe")
                }.accessibilityIdentifier("native.languageSettings")
            }
            Section(NativeL("外观")) {
                NavigationLink(value: NativeSettingsRoute.appIcon) {
                    Label(NativeL("应用图标"), systemImage: "app.badge")
                }.accessibilityIdentifier("native.appIconSettings")
                NavigationLink(value: NativeSettingsRoute.peerAppearance) {
                    Label(NativeL("设备图标与颜色"), systemImage: "paintpalette")
                }.accessibilityIdentifier("native.peerAppearanceSettings")
                Picker(selection: $appearance) {
                    Text(NativeL("跟随系统")).tag("system")
                    Text(NativeL("浅色")).tag("light")
                    Text(NativeL("深色")).tag("dark")
                } label: { Label(NativeL("外观"), systemImage: "circle.lefthalf.filled") }
            }
            Section(NativeL("关于")) {
                LabeledContent("SwiftRust", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .accessibilityIdentifier("native.aboutVersion")
                #if SWIFTRUST_APPSTORE
                NavigationLink(value: NativeSettingsRoute.support) {
                    Label {
                        Text(NativeL("支持 SwiftRust"))
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(Color.red)
                    }
                }.accessibilityIdentifier("native.supportSwiftRust")
                #endif
                Link(destination: NativeContact.feedback) {
                    Label(NativeL("发送反馈"), systemImage: "envelope")
                }.accessibilityIdentifier("native.feedback")
                if let repositoryURL = nativeRepositoryURL {
                    Link(destination: repositoryURL) { NativeBrandLinkLabel(title: NativeL("GitHub 项目仓库"), image: "GitHubBrand") }
                        .accessibilityIdentifier("native.repository")
                }
                Link(destination: NativeContact.social) {
                    NativeBrandLinkLabel(title: NativeL("在 X 上关注开发者"), image: "XBrand")
                }.accessibilityIdentifier("native.followDeveloper")
                NavigationLink(value: NativeSettingsRoute.privacy) {
                    Label(NativeL("隐私声明"), systemImage: "shield")
                }.accessibilityIdentifier("native.privacyStatement")
                NavigationLink(value: NativeSettingsRoute.openSource) {
                    Label(NativeL("开源许可与源码"), systemImage: "doc.text")
                }.accessibilityIdentifier("native.openSource")
            }.id("native.aboutSection")
        }
        .task(id: aboutRequest) {
            guard aboutRequest > 0 else { return }
            await Task.yield()
            proxy.scrollTo("native.aboutSection", anchor: .top)
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationDestination(for: NativeSettingsRoute.self) { route in
            switch route {
            case .shortcuts: NativeShortcutSettings(library: model.shortcuts).toolbar(.hidden, for: .tabBar)
            case .pointer: NativePointerSettings(model: model).toolbar(.hidden, for: .tabBar)
            case .scroll: NativeScrollSettings().toolbar(.hidden, for: .tabBar)
            case .quickDevices: NativeQuickDeviceSettings(model: model).toolbar(.hidden, for: .tabBar)
            case .urlScheme: NativeURLSchemeHelp().toolbar(.hidden, for: .tabBar)
            case .disconnect: Form {
                        Section {
                            Picker(NativeL("后台断开时间"), selection: $backgroundDisconnectDelay) {
                                Text(NativeL("立即断开")).tag(0)
                                Text(NativeL("10 秒")).tag(10)
                                Text(NativeL("30 秒")).tag(30)
                                Text(NativeL("1 分钟")).tag(60)
                                Text(NativeL("系统允许的最长时间")).tag(-1)
                            }.accessibilityIdentifier("native.backgroundDisconnectDelay")
                        } footer: {
                            Text(NativeL("切到后台后暂时保留连接，到达所选时间或系统授权到期时断开。iOS 决定可用时长，可能提前结束；返回前台后取消倒计时。"))
                        }
                        Section {
                            Toggle(isOn: $skipDisconnectConfirmation) {
                                Label(NativeL("跳过断开连接确认"), systemImage: "rectangle.portrait.and.arrow.right")
                            }.tint(nativeSwitchTint).accessibilityIdentifier("native.skipDisconnectConfirmation")
                        }
                    }.navigationTitle(NativeL("断开设置")).toolbar(.hidden, for: .tabBar)
            case .prompts: Form {
                        ForEach(model.peers) { peer in
                            Section(peer.name.isEmpty ? peer.id : peer.name) {
                                NativeSavedPromptToggle(title: NativeL("不再提示安全验证"), key: "native.skip-prompt.insecure.\(peer.id)")
                                NativeSavedPromptToggle(title: NativeL("不再提示连接错误"), key: "native.skip-prompt.reconnect.\(peer.id)")
                            }
                        }
                    }.navigationTitle(NativeL("连接提示")).toolbar(.hidden, for: .tabBar)
            case .tailscale: NativeTailscaleSettings(controller: model.tailscale, model: model).toolbar(.hidden, for: .tabBar)
            case .advanced: NativeAdvancedSettings(model: model).toolbar(.hidden, for: .tabBar)
            case .language: NativeLanguageSettings().toolbar(.hidden, for: .tabBar)
            case .appIcon: NativeAppIconSettings(model: model).toolbar(.hidden, for: .tabBar)
            case .peerAppearance: NativePeerAppearanceSettings(model: model).toolbar(.hidden, for: .tabBar)
            case .support: NativeTipJar()
            case .privacy: NativePrivacyView().toolbar(.hidden, for: .tabBar)
            case .openSource: NativeOpenSourceView().toolbar(.hidden, for: .tabBar)
            }
        }
    }
    }
}

@available(iOS 17.0, *)
private struct NativeAppIconSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedIcon = UIApplication.shared.alternateIconName
    @State private var changing = false

    var body: some View {
        Form {
            Section {
                choice(NativeL("橙色"), subtitle: NativeL("默认图标"), image: "SwiftRustIconOrange", name: nil)
                choice(NativeL("蓝色"), subtitle: NativeL("蓝色"), image: "SwiftRustIconBlue", name: "SwiftRust-Blue")
                choice(NativeL("白底橙色"), subtitle: NativeL("橙色渐变"), image: "SwiftRustIconWhiteOrange", name: "SwiftRust-WhiteOrange")
                choice(NativeL("白底蓝色"), subtitle: NativeL("蓝色渐变"), image: "SwiftRustIconWhiteBlue", name: "SwiftRust-WhiteBlue")
            } footer: {
                Text(UIApplication.shared.supportsAlternateIcons ? NativeL("切换后，系统会更新主屏幕上的应用图标，并可能显示确认提示。") : NativeL("当前设备不支持切换应用图标。"))
            }
        }
        .navigationTitle(NativeL("应用图标")).navigationBarTitleDisplayMode(.inline)
        .disabled(changing || !UIApplication.shared.supportsAlternateIcons)
        .onAppear { selectedIcon = UIApplication.shared.alternateIconName }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { selectedIcon = UIApplication.shared.alternateIconName }
        }
    }

    private func choice(_ title: String, subtitle: String, image: String, name: String?) -> some View {
        Button {
            guard selectedIcon != name, !changing else { return }
            changing = true
            Task { @MainActor in
                defer { changing = false }
                do {
                    try await UIApplication.shared.setAlternateIconName(name)
                    selectedIcon = name
                } catch { model.errorMessage = error.localizedDescription }
            }
        } label: {
            HStack(spacing: 16) {
                Image(image).resizable().frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NativeL(title)).font(.headline).foregroundStyle(.primary)
                    Text(NativeL(subtitle)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if selectedIcon == name {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(nativeRustBlue)
                }
            }.padding(.vertical, 6).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("native.appIcon." + (name?.replacingOccurrences(of: "SwiftRust-", with: "").lowercased() ?? "orange"))
        .accessibilityValue(selectedIcon == name ? NativeL("已选中") : NativeL("未选中"))
    }
}

@available(iOS 17.0, *)
struct NativeGestureHelp: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mode: String
    init(mode: String) { _mode = State(initialValue: mode) }

    var body: some View {
        List {
            Section {
                Picker(NativeL("查看操作模式"), selection: $mode) {
                    Text(NativeL("触控板")).tag("trackpad")
                    Text(NativeL("新直接触控")).tag("touch-new")
                    Text(NativeL("鼠标")).tag("mouse")
                    Text(NativeL("直接触控")).tag("touch")
                }.pickerStyle(.segmented).accessibilityIdentifier("native.gestureMode")
                Label {
                    Text(mode == "trackpad" ? NativeL("触控板：单指移动指针，双指滚动，长按拖动。") : mode == "mouse" ? NativeL("经典鼠标模式：单指移动指针，双击后移动拖动。") : mode == "touch" ? NativeL("直接触控：点击画面位置，单指移动拖动。") : NativeL("新直接触控：保留直接定位和拖动，改用双指滚动。"))
                        .font(.subheadline).foregroundStyle(.secondary)
                } icon: { NativeInputIcon(mode: mode) }
            }
            Section(mode == "trackpad" ? NativeL("触控板手势") : mode == "mouse" ? NativeL("鼠标手势") : mode == "touch" ? NativeL("直接触控手势") : NativeL("新直接触控手势")) {
                if mode == "trackpad" || mode == "mouse" {
                    gesture(NativeL("移动指针"), detail: NativeL("单指滑动，画面外的留白区域也可移动指针"), symbol: "hand.draw")
                    gesture(NativeL("左键点击"), detail: NativeL("单指轻点，在指针位置点击"), symbol: "hand.tap")
                } else {
                    gesture(NativeL("左键点击"), detail: NativeL("在远程画面内，单指轻点要操作的位置"), symbol: "hand.tap")
                }
                gesture(NativeL("双击"), detail: NativeL("在同一位置快速轻点两次"), symbol: "hand.tap", badge: "×2")
                if mode == "trackpad" {
                    gesture(NativeL("拖动"), detail: NativeL("单指长按后滑动，抬手释放"), symbol: "hand.point.up.left")
                    gesture(NativeL("右键"), detail: NativeL("双指同时轻点"), symbol: "hand.tap", badge: NativeL("双指"))
                } else {
                    gesture(NativeL("右键"), detail: NativeL("单指长按"), symbol: "hand.point.up.left")
                    gesture(NativeL("拖动"), detail: mode == "mouse" ? NativeL("双击后按住并移动，抬手释放") : NativeL("在远程画面内按住目标滑动，移出画面或抬手释放"), symbol: "hand.draw", badge: mode == "mouse" ? "×2" : nil)
                }
                if mode == "mouse" || mode == "touch" {
                    gesture(NativeL("滚轮浏览"), detail: NativeL("三指上下滑动，使用经典滚轮手势"), symbol: "arrow.up.and.down", badge: NativeL("三指"))
                    gesture(NativeL("移动画布"), detail: NativeL("双指直接同向移动画布，无需先捏合缩放"), symbol: "arrow.up.and.down.and.arrow.left.and.right", badge: NativeL("双指"))
                } else {
                    gesture(NativeL("纵向浏览"), detail: NativeL("双指同向上下滑动，画面内外均可"), symbol: "arrow.up.and.down", badge: NativeL("双指"))
                    gesture(NativeL("横向浏览"), detail: NativeL("三指同向左右滑动，画面内外均可"), symbol: "arrow.left.and.right", badge: NativeL("三指"))
                    gesture(NativeL("移动画布"), detail: NativeL("先双指捏合进入缩放，保持双指不抬起再移动；松手后恢复浏览滚动"), symbol: "arrow.up.and.down.and.arrow.left.and.right", badge: NativeL("双指"))
                }
                gesture(NativeL("缩放画布"), detail: NativeL("双指捏合缩小、张开放大，画面内外均可"), symbol: "arrow.up.left.and.arrow.down.right", badge: NativeL("双指"))
            }
        }
        .navigationTitle(NativeL("手势说明")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { dismiss() } } }
    }

    private func gesture(_ title: String, detail: String, symbol: String, badge: String? = nil) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 23, weight: .regular))
                if let badge { Text(badge).font(.caption2.weight(.medium)) }
            }.frame(width: 40).foregroundStyle(nativeRustBlue).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(NativeL(title)).font(.body.weight(.medium))
                Text(NativeL(detail)).font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }
}

@available(iOS 17.0, *)
struct NativeServerSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @Environment(\.dismiss) private var dismiss
    @State private var fields: [String: String] = [:]
    @State private var saving = false
    var body: some View {
        Form {
            Section {
                serverField(NativeL("ID 服务器"), key: "custom-rendezvous-server", hint: NativeL("留空使用默认服务器"))
                serverField(NativeL("中继服务器"), key: "relay-server", hint: "relay.example.com")
                serverField(NativeL("API 服务器"), key: "api-server", hint: "https://example.com")
                serverField(NativeL("公钥"), key: "key", hint: NativeL("服务器公钥"))
            } footer: { Text(NativeL("这些配置与已有的 SwiftRust 连接共用。留空时使用默认服务器。")) }
        }
        .navigationTitle(NativeL("服务器")).navigationBarTitleDisplayMode(.inline)
        .task { fields = model.servers }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(NativeL("取消")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? NativeL("保存中…") : NativeL("保存")) {
                    saving = true
                    Task {
                        await model.send("saveServers", arguments: fields)
                        saving = false
                        if model.errorMessage == nil { dismiss() }
                    }
                }.disabled(saving)
            }
        }
    }
    private func serverField(_ title: String, key: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NativeL(title)).font(.subheadline).foregroundStyle(.secondary)
            TextField(hint, text: Binding(get: { fields[key] ?? "" }, set: { fields[key] = $0 }), prompt: Text(hint).foregroundColor(Color(uiColor: .secondaryLabel)))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.asciiCapable)
        }.padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
struct NativePointerSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @AppStorage("native.pointer-speed") private var pointerSpeed = 1.0
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image(systemName: "cursorarrow").resizable().scaledToFit()
                        .frame(width: model.cursorSize, height: model.cursorSize)
                    Spacer()
                }.frame(height: 80)
                LabeledContent(NativeL("大小"), value: NativeF("%@ 点", String(describing: Int(model.cursorSize))))
                Slider(value: $model.cursorSize, in: 16...64, step: 1) { editing in
                    if !editing { save() }
                }.accessibilityLabel(NativeL("鼠标指针大小"))
                Button(NativeL("恢复默认（28 点）")) { model.cursorSize = 28; save() }
            }

            Section {
                LabeledContent { Text(String(format: "%.2f×", pointerSpeed)).monospacedDigit() } label: { Label(NativeL("移动速度"), systemImage: "speedometer") }
                Slider(value: $pointerSpeed, in: 0.25...3, step: 0.05)
                    .accessibilityLabel(NativeL("指针移动速度")).accessibilityIdentifier("native.pointerSpeed")
                Button(NativeL("恢复默认速度（1×）")) { pointerSpeed = 1 }
                    .accessibilityIdentifier("native.resetPointerSpeed")
            }
        }
        .navigationTitle(NativeL("鼠标指针")).navigationBarTitleDisplayMode(.inline)
    }
    private func save() {
        Task { await model.send("cursorSize", arguments: ["value": model.cursorSize]) }
    }
}

@available(iOS 17.0, *)
private struct NativeAdjustmentSlider: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String
    let id: String
    var onEnded: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = Float(range.lowerBound); slider.maximumValue = Float(range.upperBound)
        slider.minimumTrackTintColor = UIColor(red: 0, green: 113.0 / 255, blue: 1, alpha: 1)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.2)
        let thumb = UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))?.withTintColor(.white, renderingMode: .alwaysOriginal)
        slider.setThumbImage(thumb, for: .normal); slider.setThumbImage(thumb, for: .highlighted)
        slider.accessibilityLabel = label; slider.accessibilityIdentifier = id
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.ended), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }
    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self
        slider.setValue(Float(value), animated: false)
    }
    @MainActor final class Coordinator: NSObject {
        var parent: NativeAdjustmentSlider
        init(_ parent: NativeAdjustmentSlider) { self.parent = parent }
        @objc func changed(_ slider: UISlider) {
            let snapped = ((Double(slider.value) - parent.range.lowerBound) / parent.step).rounded() * parent.step + parent.range.lowerBound
            parent.value = min(max(snapped, parent.range.lowerBound), parent.range.upperBound)
        }
        @objc func ended() { parent.onEnded() }
    }
}

@available(iOS 17.0, *)
struct NativeInputAdjustmentPopup: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @AppStorage("native.pointer-speed") private var pointerSpeed = 1.0
    @AppStorage("native.scroll-speed") private var scrollSpeed = 1.0
    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
                .onTapGesture { model.showInputAdjustment = false }.accessibilityHidden(true)
            surface.padding(.horizontal, 24)
        }
        .tint(nativeRustBlue).environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain).accessibilityIdentifier("native.inputAdjustment")
    }
    @ViewBuilder private var surface: some View {
        if #available(iOS 26.0, *) {
            controls.glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            controls.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        }
    }
    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Text(NativeL("指针与滚动")).font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { model.showInputAdjustment = false } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30).background(.white.opacity(0.1), in: Circle())
                        .padding(7).contentShape(Rectangle())
                }.accessibilityLabel(NativeL("关闭调节")).accessibilityIdentifier("native.closeInputAdjustment")
            }
            VStack(spacing: 6) {
                row(NativeL("指针大小"), symbol: "cursorarrow", value: NativeF("%@ 点", String(describing: Int(model.cursorSize))))
                NativeAdjustmentSlider(value: $model.cursorSize, range: 16...64, step: 1, label: NativeL("指针大小"), id: "native.inputPointerSize", onEnded: saveSize).frame(height: 32)
            }
            VStack(spacing: 6) {
                row(NativeL("移动速度"), symbol: "speedometer", value: String(format: "%.2f×", pointerSpeed))
                NativeAdjustmentSlider(value: $pointerSpeed, range: 0.25...3, step: 0.05, label: NativeL("移动速度"), id: "native.inputPointerSpeed").frame(height: 32)
            }
            VStack(spacing: 6) {
                row(NativeL("滚动速度"), symbol: "arrow.up.and.down", value: String(format: "%.2f×", scrollSpeed))
                NativeAdjustmentSlider(value: $scrollSpeed, range: 0.25...3, step: 0.05, label: NativeL("滚动速度"), id: "native.inputScrollSpeed").frame(height: 32)
            }
            Divider().overlay(.white.opacity(0.12))
            Button(NativeL("恢复默认")) { model.cursorSize = 28; pointerSpeed = 1; scrollSpeed = 1; saveSize() }
                .font(.body.weight(.semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("native.resetInputAdjustment")
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .padding(20).frame(maxWidth: 340)
    }
    private func row(_ title: String, symbol: String, value: String) -> some View {
        HStack {
            Label(NativeL(title), systemImage: symbol).font(.body.weight(.medium))
            Spacer()
            Text(value).font(.body.monospacedDigit()).foregroundStyle(.white)
        }
    }
    private func saveSize() { Task { await model.send("cursorSize", arguments: ["value": model.cursorSize]) } }
}

@available(iOS 17.0, *)
struct NativeResolutionAdjustmentPopup: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @State private var width = ""
    @State private var height = ""
    private var display: NativeDisplay? { model.displays.first { $0.id == model.displayIndex } }
    private var canChange: Bool { model.connected && model.keyboardAllowed && !model.sessionToggle("view-only") }
    private var custom: NativeResolution? {
        guard let w = Int(width), let h = Int(height), (64...8192).contains(w), (64...8192).contains(h) else { return nil }
        return NativeResolution(width: w, height: h)
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.12).ignoresSafeArea()
                    .onTapGesture { model.showResolutionAdjustment = false }.accessibilityHidden(true)
                surface(height: geometry.size.height)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("native.resolutionPanel")
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(nativeRustBlue).environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain).accessibilityIdentifier("native.resolutionAdjustment")
    }
    @ViewBuilder private func surface(height: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            controls(height: height).fixedSize(horizontal: false, vertical: true).glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            controls(height: height).fixedSize(horizontal: false, vertical: true).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        }
    }
    private func controls(height: CGFloat) -> some View {
        let rows = max(1, (model.resolutionChoices.count + 1) / 2)
        let gridHeight = min(CGFloat(rows * 44 + (rows - 1) * 8), max(44, min(240, height - (display?.customResolution == true ? 340 : 270))))
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NativeL("分辨率")).font(.headline)
                    Text(model.currentResolution.map { NativeF("当前桌面 %@", $0.title) } ?? NativeL("等待远端画面"))
                        .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button { model.showResolutionAdjustment = false } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30).background(.white.opacity(0.1), in: Circle())
                        .padding(7).contentShape(Rectangle())
                }.accessibilityLabel(NativeL("关闭分辨率调节")).accessibilityIdentifier("native.closeResolutionAdjustment")
            }
            if display?.customResolution == true {
                HStack(spacing: 8) {
                    dimension(NativeL("宽度"), text: $width, id: "native.resolutionWidth")
                    Text("×").foregroundStyle(.white.opacity(0.5))
                    dimension(NativeL("高度"), text: $height, id: "native.resolutionHeight")
                    Button(NativeL("应用")) { if let custom { model.changeResolution(custom) } }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(height: 40)
                        .background(nativeRustBlue.opacity(custom != nil && canChange ? 1 : 0.25), in: RoundedRectangle(cornerRadius: 10))
                        .disabled(custom == nil || !canChange)
                }
            }
            if model.resolutionChoices.isEmpty {
                Label(NativeL("远端尚未提供可用分辨率"), systemImage: "display").font(.footnote)
                    .foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, minHeight: 44)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(model.resolutionChoices) { resolution in
                            let selected = model.currentResolution == resolution
                            Button { model.changeResolution(resolution) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: selected ? "checkmark.circle.fill" : resolution.width >= resolution.height ? "rectangle" : "rectangle.portrait")
                                        .foregroundStyle(selected ? nativeRustBlue : .white.opacity(0.55))
                                    Text(resolution.title).font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.85)
                                }.frame(maxWidth: .infinity, minHeight: 44)
                                    .background(selected ? nativeRustBlue.opacity(0.18) : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? nativeRustBlue.opacity(0.5) : .white.opacity(0.06), lineWidth: 1))
                            }.accessibilityIdentifier("native.resolution.\(resolution.id)")
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }.frame(height: gridHeight).disabled(!canChange).opacity(canChange ? 1 : 0.45)
            }
            Button {
                if let original = display?.originalResolution { model.changeResolution(original) }
                else { model.canvas?.fit() }
            } label: {
                Label(display?.originalResolution == nil ? NativeL("画面复位") : NativeL("恢复原分辨率"), systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.medium)).foregroundStyle(nativeRustBlue)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }.disabled(display?.originalResolution != nil && !canChange)
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .padding(18).frame(maxWidth: 360)
    }
    private func dimension(_ title: String, text: Binding<String>, id: String) -> some View {
        TextField(title, text: text, prompt: Text(NativeL(title)).foregroundStyle(.white.opacity(0.4)))
            .keyboardType(.numberPad).font(.subheadline.monospacedDigit()).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier(id)
    }
}

@available(iOS 17.0, *)
struct NativeResolutionSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @State private var width = ""
    @State private var height = ""
    private var canChange: Bool { model.connected && model.keyboardAllowed && !model.sessionToggle("view-only") }
    private var display: NativeDisplay? { model.displays.first { $0.id == model.displayIndex } }
    private var custom: NativeResolution? {
        guard let w = Int(width), let h = Int(height), (64...8192).contains(w), (64...8192).contains(h) else { return nil }
        return NativeResolution(width: w, height: h)
    }
    var body: some View {
        Form {
            if let current = model.currentResolution {
                Section { LabeledContent(NativeL("当前桌面"), value: current.title) }
            }
            if let original = display?.originalResolution {
                Section { Button(NativeF("恢复原分辨率（%@）", String(describing: original.title))) { model.changeResolution(original) } }.disabled(!canChange)
            }
            Section(NativeL("可用分辨率")) {
                ForEach(model.resolutionChoices) { resolution in
                    Button { model.changeResolution(resolution) } label: {
                        HStack {
                            Text(resolution.title)
                            Spacer()
                            if model.currentResolution == resolution { Image(systemName: "checkmark").foregroundStyle(nativeRustBlue) }
                        }
                    }.accessibilityIdentifier("native.resolution.\(resolution.id)")
                        .accessibilityAddTraits(model.currentResolution == resolution ? .isSelected : [])
                }
                if model.resolutionChoices.isEmpty { Text(NativeL("远端尚未提供可用分辨率")).foregroundStyle(.secondary) }
            }.disabled(!canChange)
            if display?.customResolution == true {
                Section {
                    TextField(NativeL("宽度"), text: $width).keyboardType(.numberPad).accessibilityIdentifier("native.resolutionWidth")
                    TextField(NativeL("高度"), text: $height).keyboardType(.numberPad).accessibilityIdentifier("native.resolutionHeight")
                    Button(NativeL("应用分辨率")) { if let custom { model.changeResolution(custom) } }.disabled(custom == nil || !canChange)
                } header: { Text(NativeL("自定义分辨率")) } footer: { Text(NativeL("宽度和高度均为 64–8192，需由远端显示器支持。")) }
            }
        }
        .navigationTitle(NativeL("分辨率")).navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
struct NativeScrollSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @AppStorage("native.scroll-speed") private var scrollSpeed = 1.0
    var body: some View {
        Form {
            Section {
                LabeledContent { Text(String(format: "%.2f×", scrollSpeed)).monospacedDigit() } label: { Label(NativeL("滚动速度"), systemImage: "arrow.up.and.down") }
                Slider(value: $scrollSpeed, in: 0.25...3, step: 0.05)
                    .accessibilityLabel(NativeL("滚动速度")).accessibilityIdentifier("native.scrollSpeed")
                Button(NativeL("恢复默认速度（1×）")) { scrollSpeed = 1 }
                    .accessibilityIdentifier("native.resetScrollSpeed")
            }
        }
        .navigationTitle(NativeL("滚动速度")).navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
struct NativeAdvancedSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    var body: some View {
        Form {
            if !model.hideNetwork {
                Section(NativeL("网络")) {
                    if !model.hideProxy {
                        NavigationLink(NativeL("网络代理")) { NativeProxySettings(model: model) }
                    }
                    option(NativeL("使用 WebSocket"), key: "allow-websocket")
                    option(NativeL("TCP 打洞"), key: "enable-tcp-punch")
                    option(NativeL("UDP 打洞"), key: "enable-udp-punch")
                    option(NativeL("IPv6 点对点连接"), key: "enable-ipv6-punch")
                    option(NativeL("WebRTC 点对点连接"), key: "enable-webrtc")
                }
                Section {
                    option(NativeL("允许不安全 TLS 回退"), key: "allow-insecure-tls-fallback")
                } footer: { Text(NativeL("开启后可能降低连接安全性。仅在了解服务器配置及风险时使用。")) }
            }
            Section(NativeL("会话")) {
                option(NativeL("连接时保持屏幕常亮"), key: "keep-awake-during-outgoing-sessions")
            }
            Section(NativeL("默认显示设置")) {
                choice(NativeL("画面缩放"), key: "view-style", choices: [(NativeL("适合窗口"), "adaptive"), (NativeL("原始尺寸"), "original")], fallback: "adaptive")
                choice(NativeL("图像质量"), key: "image-quality", choices: [(NativeL("均衡"), "balanced"), (NativeL("最佳画质"), "best"), (NativeL("优先响应"), "low"), (NativeL("自定义"), "custom")], fallback: "balanced")
                if model.defaults["image-quality"] == "custom" {
                    numeric(NativeL("画质"), key: "custom_image_quality", range: 10...100, fallback: 50)
                    numeric(NativeL("帧率"), key: "custom-fps", range: 5...120, fallback: 30)
                }
                choice(NativeL("视频编码"), key: "codec-preference", choices: codecChoices, fallback: "auto")
            }
            Section(NativeL("其他默认选项")) {
                ForEach(model.otherDefaults.indices, id: \.self) { index in
                    let row = model.otherDefaults[index]
                    if let key = row["key"] as? String, let title = row["title"] as? String {
                        Toggle(title, isOn: Binding<Bool>(get: { row["value"] as? Bool ?? false }, set: { model.setting(key, $0) })).tint(nativeSwitchTint)
                            .disabled(row["fixed"] as? Bool ?? false)
                    }
                }
            }
        }
        .navigationTitle(NativeL("高级设置")).navigationBarTitleDisplayMode(.inline)
    }
    private var codecChoices: [(String, String)] {
        var choices = [(NativeL("自动"), "auto"), ("VP8", "vp8"), ("VP9", "vp9"), ("AV1", "av1")]
        if model.codecs["h264"] == true { choices.append(("H.264", "h264")) }
        if model.codecs["h265"] == true { choices.append(("H.265", "h265")) }
        return choices
    }
    private func option(_ title: String, key: String) -> some View {
        Toggle(title, isOn: Binding<Bool>(get: { model.settings[key] ?? false }, set: { model.setting(key, $0) })).tint(nativeSwitchTint)
            .disabled(model.fixed.contains(key))
    }
    private func choice(_ title: String, key: String, choices: [(String, String)], fallback: String) -> some View {
        Picker(title, selection: Binding<String>(get: {
            let current = model.defaults[key] ?? ""
            return choices.contains(where: { $0.1 == current }) ? current : fallback
        }, set: { model.setting(key, $0) })) {
            ForEach(choices, id: \.1) { entry in Text(entry.0).tag(entry.1) }
        }.disabled(model.fixed.contains(key))
    }
    private func numeric(_ title: String, key: String, range: ClosedRange<Int>, fallback: Int) -> some View {
        let current = Double(model.defaults[key] ?? "").map { Int($0) } ?? fallback
        return Stepper("\(title)：\(current)", value: Binding(get: { current }, set: { model.setting(key, String($0)) }), in: range)
            .disabled(model.fixed.contains(key))
    }
}

@available(iOS 17.0, *)
struct NativeConnectionPrompt: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    let prompt: NativeConnectionMessage
    @State private var password = ""
    @State private var username = ""
    @State private var osPassword = ""
    @State private var code = ""
    @State private var remember = false
    @State private var skipPrompt = false
    var body: some View {
        Form {
            Section {
                Label(prompt.password || prompt.twoFactor ? model.remoteIdentity : title, systemImage: prompt.insecure ? "exclamationmark.shield" : prompt.password || prompt.twoFactor ? "lock" : "network")
                    .font(.headline).foregroundStyle(prompt.insecure ? .orange : .primary)
                if !prompt.text.isEmpty { Text(NativeL(prompt.text)).font(.subheadline).textSelection(.enabled) }
            }
            if prompt.twoFactor {
                Section(NativeL("双重验证")) {
                    TextField(NativeL("验证码"), text: $code, prompt: Text(NativeL("验证码")).foregroundColor(Color(uiColor: .secondaryLabel))).keyboardType(.numberPad).textContentType(.oneTimeCode)
                }
            } else if prompt.password {
                Section(NativeL("连接凭据")) {
                    SecureField(NativeL("远程访问密码"), text: $password, prompt: Text(NativeL("远程访问密码")).foregroundColor(Color(uiColor: .secondaryLabel))).textContentType(.password)
                    DisclosureGroup(NativeL("操作系统登录（如需）")) {
                        TextField(NativeL("用户名"), text: $username, prompt: Text(NativeL("用户名")).foregroundColor(Color(uiColor: .secondaryLabel))).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField(NativeL("系统密码"), text: $osPassword, prompt: Text(NativeL("系统密码")).foregroundColor(Color(uiColor: .secondaryLabel)))
                    }
                    Toggle(NativeL("记住访问密码"), isOn: $remember).tint(nativeSwitchTint)
                }
            }
            if prompt.insecure || prompt.connectionError {
                Section { Toggle(NativeL("不再提示（此设备）"), isOn: $skipPrompt).tint(nativeSwitchTint) }
            }
            Section {
                if prompt.insecure {
                    Button(NativeL("继续")) { model.continuePrompt(prompt, skip: skipPrompt) }
                        .keyboardShortcut(.defaultAction)
                        .foregroundStyle(.orange)
                } else if prompt.twoFactor {
                    Button(NativeL("验证")) { model.resumeConnection("twoFactor", ["code": code, "trust": false]) }.disabled(code.isEmpty)
                } else if prompt.password {
                    Button(NativeL("连接")) { model.resumeConnection("login", ["username": username, "osPassword": osPassword, "password": password, "remember": remember]) }
                } else {
                    Button(prompt.hasRetry ? NativeL("重新连接") : NativeL("好")) { model.continuePrompt(prompt, skip: skipPrompt) }
                        .keyboardShortcut(.defaultAction)
                }
                Button(NativeL("断开连接"), role: .destructive) { model.requestDisconnect() }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
        .onAppear {
            skipPrompt = model.promptIsSkipped(prompt)
        }
        .onChange(of: skipPrompt) { _, skip in
            if !prompt.insecure || !skip { model.setPromptSkipped(prompt, skip) }
        }
        .onDisappear { password = ""; osPassword = ""; code = "" }
    }
    private var title: String {
        if prompt.insecure { return NativeL("无法验证加密连接") }
        if prompt.twoFactor { return NativeL("双重验证") }
        if prompt.password { return NativeL("连接认证") }
        return NativeL(prompt.title)
    }
}

@available(iOS 17.0, *)
struct NativeAccountView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @Environment(\.dismiss) private var dismiss
    @State private var info: [String: Any] = [:]
    @State private var username = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var challenge: String?
    @State private var secret = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(NativeL("账号服务器")) {
                Text(info["server"] as? String ?? NativeL("正在加载…"))
                    .font(.subheadline).foregroundStyle(.secondary)
                NavigationLink(NativeL("服务器设置")) { NativeServerSettings(model: model).onDisappear { load() } }.disabled(busy)
            }
            if info["enabled"] as? Bool == false {
                Section { Text(NativeL("管理员已停用账号登录")) }
            } else if !model.accountName.isEmpty {
                Section(NativeL("当前账号")) {
                    Label(model.accountName, systemImage: "person.crop.circle")
                    Button(NativeL("退出登录"), role: .destructive) { Task { await logout() } }.disabled(busy)
                }
            } else {
                Section(challenge == nil ? NativeL("登录") : NativeL("安全验证")) {
                    if challenge == nil {
                        TextField(NativeL("用户名或邮箱"), text: $username, prompt: Text(NativeL("用户名或邮箱")).foregroundColor(Color(uiColor: .secondaryLabel)))
                            .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("native.accountUsername")
                        SecureField(NativeL("密码"), text: $password, prompt: Text(NativeL("密码")).foregroundColor(Color(uiColor: .secondaryLabel))).textContentType(.password)
                            .accessibilityIdentifier("native.accountPassword")
                    } else {
                        Text(challenge == "email_check" ? NativeL("请输入邮件中的验证码") : NativeL("请输入双重验证器中的验证码"))
                        TextField(NativeL("验证码"), text: $verificationCode, prompt: Text(NativeL("验证码")).foregroundColor(Color(uiColor: .secondaryLabel))).textContentType(.oneTimeCode).keyboardType(.numberPad)
                    }
                    Button { Task { await login() } } label: {
                        HStack {
                            if busy { ProgressView() }
                            Text(challenge == nil ? NativeL("登录") : NativeL("验证并登录"))
                        }
                    }
                    .disabled(busy || info.isEmpty || (challenge == nil ? username.isEmpty || password.isEmpty : verificationCode.isEmpty))
                    .accessibilityIdentifier("native.accountSubmit")
                    if challenge != nil {
                        Button(NativeL("返回密码登录")) { challenge = nil; secret = ""; verificationCode = "" }.disabled(busy)
                    }
                }
            }
            if let errorMessage { Section { Text(NativeL(errorMessage)).foregroundStyle(.red) } }
        }
        .navigationTitle(model.accountName.isEmpty ? NativeL("登录") : NativeL("账号"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { dismiss() }.disabled(busy) } }
        .interactiveDismissDisabled(busy)
        .task { load() }
        .onDisappear { password = ""; verificationCode = ""; secret = ""; info = [:] }
    }

    private func load() {
        do { info = try NativeRustCore.call("accountInfo"); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    private func request(_ path: String, body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        let server = (info["server"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(server)/api/\(path)"), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            throw NSError(domain: "SwiftRust", code: 1, userInfo: [NSLocalizedDescriptionKey: NativeL("请先在服务器设置中配置有效的 API 服务器")])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let value = data.isEmpty ? [:] : (try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:])
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(status) || value["error"] != nil {
            throw NSError(domain: "SwiftRust", code: status, userInfo: [NSLocalizedDescriptionKey: value["error"] as? String ?? NativeF("服务器返回 HTTP %@", String(describing: status))])
        }
        return value
    }

    private func login() async {
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            var body: [String: Any] = ["username": username, "id": info["id"] ?? "", "uuid": info["uuid"] ?? "", "autoLogin": true, "deviceInfo": info["deviceInfo"] ?? [:]]
            if challenge == nil {
                body["type"] = "account"; body["password"] = password
            } else {
                body["type"] = "email_code"; body["verificationCode"] = verificationCode; body["secret"] = secret
                if challenge != "email_check" { body["tfaCode"] = verificationCode }
            }
            let response = try await request("login", body: body)
            if let token = response["access_token"] as? String, !token.isEmpty, let user = response["user"] as? [String: Any] {
                let userData = try JSONSerialization.data(withJSONObject: user)
                _ = try NativeRustCore.call("saveAccount", ["token": token, "user": String(decoding: userData, as: UTF8.self)])
                await model.refresh(); password = ""; secret = ""; verificationCode = ""; load()
            } else if let type = response["type"] as? String, ["email_check", "tfa_check"].contains(type) {
                challenge = type; secret = response["secret"] as? String ?? ""; password = ""
                if let user = response["user"] as? [String: Any], let name = user["name"] as? String { username = name }
            } else {
                throw NSError(domain: "SwiftRust", code: 2, userInfo: [NSLocalizedDescriptionKey: NativeL("服务器返回了无法识别的登录结果")])
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func logout() async {
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            _ = try await request("logout", body: ["id": info["id"] ?? "", "uuid": info["uuid"] ?? ""], token: info["token"] as? String)
            _ = try NativeRustCore.call("saveAccount", ["token": "", "user": ""])
            await model.refresh(); load()
        } catch { errorMessage = error.localizedDescription }
    }
}

@available(iOS 17.0, *)
private struct NativeSavedPromptToggle: View {
    @ObservedObject private var localization = NativeLocalization.shared
    let title: String
    @AppStorage private var skipped: Bool
    init(title: String, key: String) {
        self.title = title
        _skipped = AppStorage(wrappedValue: false, key)
    }
    var body: some View { Toggle(title, isOn: $skipped).tint(nativeSwitchTint) }
}

@available(iOS 17.0, *)
private enum NativePeerIconCatalog {
    static let icons: [(title: String, symbol: String)] = [
        ("macOS", "apple.logo"), ("Mac mini", "macmini"), ("iMac", "desktopcomputer"),
        ("Windows", "pc"), ("Linux", "terminal"), ("Android", "apps.iphone"),
        ("iPhone", "iphone"), ("iPad", "ipad"), ("服务器", "server.rack"),
        ("笔记本", "laptopcomputer"), ("存储设备", "externaldrive"), ("网络设备", "network")
    ]
    static let colors: [(name: String, title: String, color: Color)] = [
        ("primary", "默认", .primary), ("blue", "蓝色", nativeRustBlue), ("green", "绿色", .green),
        ("orange", "橙色", .orange), ("purple", "紫色", .purple), ("red", "红色", .red), ("teal", "青色", .teal)
    ]
    static func color(_ name: String) -> Color { colors.first { $0.name == name }?.color ?? .primary }
}

@available(iOS 17.0, *)
struct NativePeerBadge: View {
    @ObservedObject private var localization = NativeLocalization.shared
    let peer: NativePeer
    @AppStorage private var icon: String
    @AppStorage private var colorName: String
    init(peer: NativePeer) {
        self.peer = peer
        _icon = AppStorage(wrappedValue: "", "native.peer-icon.\(peer.id)")
        _colorName = AppStorage(wrappedValue: "primary", "native.peer-icon-color.\(peer.id)")
    }
    var body: some View {
        Image(systemName: icon.isEmpty ? peer.symbol : icon)
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(NativePeerIconCatalog.color(colorName))
            .frame(width: 48, height: 48)
            .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

@available(iOS 17.0, *)
private struct NativePeerAppearanceSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    var body: some View {
        List {
            Section(NativeL("设备")) {
                if model.peers.isEmpty { Text(NativeL("连接设备后，可在这里设置设备图标与颜色。")).foregroundStyle(.secondary) }
                ForEach(model.peers) { peer in
                    NavigationLink { NativePeerAppearanceEditor(peer: peer) } label: {
                        HStack(spacing: 12) {
                            NativePeerBadge(peer: peer)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(peer.name.isEmpty ? peer.id : peer.name)
                                Text(peer.id).font(.system(.subheadline, design: .rounded, weight: .medium).monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }.accessibilityIdentifier("native.peerAppearance.\(peer.id)")
                }
            }
            Section {
                NavigationLink(NativeL("常用系统图标表")) {
                    List {
                        ForEach(NativePeerIconCatalog.icons, id: \.title) { entry in
                            Label(NativeL(entry.title), systemImage: entry.symbol).labelStyle(.titleAndIcon)
                        }
                    }.navigationTitle(NativeL("常用系统图标"))
                }
            }
        }.navigationTitle(NativeL("设备图标与颜色")).navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
private struct NativePeerAppearanceEditor: View {
    @ObservedObject private var localization = NativeLocalization.shared
    let peer: NativePeer
    @AppStorage private var icon: String
    @AppStorage private var colorName: String
    init(peer: NativePeer) {
        self.peer = peer
        _icon = AppStorage(wrappedValue: "", "native.peer-icon.\(peer.id)")
        _colorName = AppStorage(wrappedValue: "primary", "native.peer-icon-color.\(peer.id)")
    }
    var body: some View {
        Form {
            Section(NativeL("预览")) {
                HStack(spacing: 14) {
                    NativePeerBadge(peer: peer)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(peer.name.isEmpty ? peer.id : peer.name).font(.headline)
                        Text(peer.id).font(.system(.subheadline, design: .rounded, weight: .medium).monospacedDigit()).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 4)
            }
            Section(NativeL("图标颜色")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 12) {
                    ForEach(NativePeerIconCatalog.colors, id: \.name) { entry in
                        Button { colorName = entry.name } label: {
                            VStack(spacing: 6) {
                                Circle().fill(entry.color).frame(width: 28, height: 28)
                                    .padding(5).overlay(Circle().stroke(colorName == entry.name ? nativeRustBlue : .clear, lineWidth: 2))
                                Text(NativeL(entry.title)).font(.caption).foregroundStyle(.primary)
                            }.frame(maxWidth: .infinity, minHeight: 64)
                        }.buttonStyle(.plain).accessibilityLabel(entry.title)
                            .accessibilityAddTraits(colorName == entry.name ? .isSelected : [])
                    }
                }.padding(.vertical, 4)
            }
            Section(NativeL("常用系统与设备图标")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 12) {
                    ForEach(NativePeerIconCatalog.icons, id: \.title) { entry in
                        Button { icon = entry.symbol } label: {
                            VStack(spacing: 8) {
                                Image(systemName: entry.symbol).font(.system(size: 25)).foregroundStyle(NativePeerIconCatalog.color(colorName))
                                Text(NativeL(entry.title)).font(.caption).foregroundStyle(.primary)
                            }.frame(maxWidth: .infinity, minHeight: 68)
                                .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(icon == entry.symbol ? nativeRustBlue : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityLabel(entry.title)
                            .accessibilityAddTraits(icon == entry.symbol ? .isSelected : [])
                    }
                }.padding(.vertical, 4)
            }
            Section { Button(NativeL("恢复默认")) { icon = ""; colorName = "primary" }.accessibilityIdentifier("native.resetPeerAppearance") }
        }.navigationTitle(NativeL("设备图标")).navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
struct NativeSessionSettingsView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                LabeledContent(NativeL("设备"), value: model.remoteName)
                LabeledContent(NativeL("状态"), value: model.connected ? NativeL("已连接") : model.status)
                if model.connectionFailure?.hasRetry == true { Button(NativeL("重新连接")) { model.resumeConnection("reconnect") } }
                Button(role: .destructive) { model.requestDisconnect() } label: { Label(NativeL("断开连接"), systemImage: "power") }
                    .accessibilityIdentifier("native.disconnect")
            }
            if model.remoteKind != .camera {
                Section(NativeL("输入与指针")) {
                    Picker(NativeL("输入模式"), selection: Binding(get: { model.inputMode }, set: model.setMode)) {
                        Text(NativeL("触控板")).tag("trackpad")
                        Text(NativeL("新直接触控")).tag("touch-new")
                        Text(NativeL("鼠标")).tag("mouse")
                        Text(NativeL("直接触控")).tag("touch")
                    }
                    NavigationLink { NativePointerSettings(model: model) } label: { Label(NativeL("指针大小"), systemImage: "cursorarrow") }
                    toggle(NativeL("显示远端指针"), "show-remote-cursor")
                    toggle(NativeL("反转滚轮"), "reverse-mouse-wheel")
                    toggle(NativeL("交换左右键"), "swap-left-right-mouse")
                    Button(NativeL("右键点击")) { Task { await model.send("rightClick") } }.disabled(!model.connected || model.sessionToggle("view-only"))
                    NavigationLink { NativeGestureHelp(mode: model.inputMode) } label: { Label(NativeL("手势说明"), systemImage: "hand.draw") }
                }
            }
            Section(NativeL("画面")) {
                if model.displays.count > 1 {
                    Picker(NativeL("显示器"), selection: Binding(get: { model.displayIndex }, set: model.chooseDisplay)) {
                        ForEach(model.displays) { display in Text(NativeF("显示器 %@", String(describing: display.id + 1))).tag(display.id) }
                    }
                }
                Button(NativeL("适合屏幕")) { Task { await model.send("fit") } }
                Button(NativeL("原始尺寸")) { Task { await model.send("original") } }
                Toggle(isOn: Binding(get: { model.canvasLocked }, set: { value in Task { await model.send("lockCanvas", arguments: ["value": value]) } })) { Label(NativeL("锁定画布"), systemImage: model.canvasLocked ? "lock" : "lock.open") }.tint(.green)
                Picker(NativeL("画质"), selection: Binding(get: { model.sessionQuality }, set: { model.sessionOption("image-quality", $0) })) {
                    Text(NativeL("最佳画质")).tag("best")
                    Text(NativeL("平衡")).tag("balanced")
                    Text(NativeL("响应优先")).tag("low")
                    Text(NativeL("自定义")).tag("custom")
                }.disabled(!model.connected || model.fixed.contains("image-quality"))
                if model.sessionQuality == "custom" {
                    VStack(alignment: .leading) {
                        Text(NativeF("图像质量：%@", String(describing: Int(model.customQuality))))
                        Slider(value: $model.customQuality, in: 10...100, step: 1, onEditingChanged: { editing in if !editing { model.sessionOption("custom_image_quality", Int(model.customQuality)) } })
                    }.disabled(!model.connected || model.fixed.contains("custom_image_quality"))
                    VStack(alignment: .leading) {
                        Text(NativeF("帧率上限：%@ FPS", String(describing: Int(model.customFPS))))
                        Slider(value: $model.customFPS, in: 5...120, step: 1, onEditingChanged: { editing in if !editing { model.sessionOption("custom-fps", Int(model.customFPS)) } })
                    }.disabled(!model.connected || model.fixed.contains("custom-fps"))
                }
                Picker(NativeL("视频编码"), selection: Binding(get: { model.sessionCodec }, set: { model.sessionOption("codec-preference", $0) })) {
                    Text(NativeL("自动")).tag("auto")
                    ForEach(["vp8", "vp9", "av1", "h264", "h265"], id: \.self) { codec in
                        if codec == "vp9" || model.sessionCodecs[codec] == true { Text(codec.uppercased()).tag(codec) }
                    }
                }.disabled(!model.connected || model.fixed.contains("codec-preference"))
            }
            if model.remoteKind != .camera {
                Section(NativeL("声音与访问")) {
                    toggle(NativeL("静音"), "disable-audio")
                    toggle(NativeL("只读模式"), "view-only")
                    toggle(NativeL("禁用剪贴板"), "disable-clipboard")
                    toggle(NativeL("结束会话后锁屏"), "lock-after-session-end")
                    if model.remoteKind == .desktop {
                        Button(NativeL("发送系统密码")) { model.sendSavedOSPassword() }.disabled(!model.connected)
                        NavigationLink(NativeL("自动登录")) { NativeOSPasswordSettings(model: model) }.disabled(!model.connected)
                    }
                }
            }
        }
        .navigationTitle(NativeL("会话设置")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NativeL("完成")) { dismiss() } } }
        .task(id: model.connected) { if model.connected { await model.send("sessionSettings") } }
    }
    private func toggle(_ title: String, _ key: String) -> some View {
        Toggle(title, isOn: Binding(get: { model.sessionToggle(key) }, set: { model.sessionOption(key, $0) }))
            .tint(.green).disabled(!model.connected || model.fixed.contains(key))
    }
}

@available(iOS 17.0, *)
struct NativeSessionMenuContents: View {
    @ObservedObject private var localization = NativeLocalization.shared
    @ObservedObject var model: NativeShellModel
    @AppStorage("native.show-connection-stats") private var showStatistics = false
    var body: some View {
        Section(model.remoteName) {
            if model.connectionFailure?.hasRetry == true { Button(NativeL("重新连接"), systemImage: "arrow.clockwise") { model.resumeConnection("reconnect") } }
        }
        Menu {
            if model.remoteKind != .camera {
                Picker(NativeL("输入模式"), selection: Binding(get: { model.inputMode }, set: model.setMode)) {
                    Text(NativeL("触控板")).tag("trackpad"); Text(NativeL("新直接触控")).tag("touch-new")
                    Text(NativeL("鼠标")).tag("mouse"); Text(NativeL("直接触控")).tag("touch")
                }
                Button(NativeL("指针与滚动"), systemImage: "slider.horizontal.3") {
                    model.showOSPassword = false; model.showResolutionAdjustment = false; model.canvas?.hideSystemKeyboard(); model.showInputAdjustment = true
                }.accessibilityIdentifier("native.inputAdjustmentButton")
                toggle(NativeL("显示远端指针"), "show-remote-cursor")
                Picker(NativeL("滚动方向"), selection: Binding(get: { model.sessionToggle("reverse-mouse-wheel") }, set: { model.sessionOption("reverse-mouse-wheel", $0) })) {
                    Text(NativeL("标准")).tag(false)
                    Text(NativeL("反向")).tag(true)
                }.disabled(!model.connected || model.fixed.contains("reverse-mouse-wheel"))
                Button(NativeL("手势说明"), systemImage: "hand.draw") { open(.gestures) }
            }
        } label: { Label(NativeL("控制模式"), systemImage: "cursorarrow.motionlines") }
        Menu {
            if model.displays.count > 1 {
                Picker(NativeL("显示器"), selection: Binding(get: { model.displayIndex }, set: model.chooseDisplay)) {
                    ForEach(model.displays) { display in Text(NativeF("显示器 %@", String(describing: display.id + 1))).tag(display.id) }
                }
            }
            if model.remoteKind == .desktop {
                Button(NativeL("分辨率"), systemImage: "rectangle.expand.vertical") {
                    model.showOSPassword = false; model.showInputAdjustment = false; model.canvas?.hideSystemKeyboard(); model.showResolutionAdjustment = true
                }
                    .accessibilityIdentifier("native.resolutionSettings")
            }
            Button(NativeL("适合屏幕"), systemImage: "arrow.up.left.and.arrow.down.right") { Task { await model.send("fit") } }
            Button(NativeL("原始尺寸"), systemImage: "1.magnifyingglass") { Task { await model.send("original") } }
            Toggle(isOn: Binding(get: { model.limitZoomToWidth }, set: model.setLimitZoomToWidth)) {
                Label(NativeL("最小缩放为屏幕宽度"), systemImage: "arrow.left.and.right")
            }.accessibilityIdentifier("native.limitZoomToWidth")
            Toggle(isOn: Binding(get: { model.canvasLocked }, set: { value in Task { await model.send("lockCanvas", arguments: ["value": value]) } })) { Label(NativeL("锁定画布"), systemImage: model.canvasLocked ? "lock" : "lock.open") }
        } label: { Label(NativeL("显示画面"), systemImage: "display") }
        Menu {
            Picker(NativeL("画质"), selection: Binding(get: { model.sessionQuality }, set: { model.sessionOption("image-quality", $0) })) {
                Text(NativeL("最佳画质")).tag("best"); Text(NativeL("平衡")).tag("balanced"); Text(NativeL("响应优先")).tag("low"); Text(NativeL("自定义")).tag("custom")
            }.disabled(!model.connected || model.fixed.contains("image-quality"))
            Picker(NativeL("视频编码"), selection: Binding(get: { model.sessionCodec }, set: { model.sessionOption("codec-preference", $0) })) {
                Text(NativeL("自动")).tag("auto")
                ForEach(["vp8", "vp9", "av1", "h264", "h265"], id: \.self) { codec in
                    if codec == "vp9" || model.sessionCodecs[codec] == true { Text(codec.uppercased()).tag(codec) }
                }
            }.disabled(!model.connected || model.fixed.contains("codec-preference"))
        } label: { Label(NativeL("画质与编码"), systemImage: "photo") }
        if model.remoteKind != .camera {
            Menu {
                Toggle(isOn: $showStatistics) { Label(NativeL("显示统计信息"), systemImage: "chart.bar.xaxis") }
                toggle(NativeL("静音"), "disable-audio"); toggle(NativeL("只读模式"), "view-only")
                toggle(NativeL("禁用剪贴板"), "disable-clipboard")
                toggle(NativeL("结束会话后锁屏"), "lock-after-session-end")
                if model.remoteKind == .desktop {
                    Button(NativeL("发送系统密码")) { model.sendSavedOSPassword() }.disabled(!model.connected)
                    Button(NativeL("自动登录")) { open(.osPassword) }.disabled(!model.connected)
                }
            } label: { Label(NativeL("声音与访问"), systemImage: "speaker.wave.2") }
        }
        Section {
            Button(role: .destructive) { model.canvas?.hideSystemKeyboard(); model.requestDisconnect() } label: { Label(NativeL("断开连接"), systemImage: "power") }
                .accessibilityIdentifier("native.disconnect")
        }
    }
    private func toggle(_ title: String, _ key: String) -> some View {
        Toggle(title, isOn: Binding(get: { model.sessionToggle(key) }, set: { model.sessionOption(key, $0) }))
            .disabled(!model.connected || model.fixed.contains(key))
    }
    private func open(_ sheet: NativeSheet) { model.showResolutionAdjustment = false; model.showInputAdjustment = false; model.canvas?.hideSystemKeyboard(); if sheet == .osPassword { model.showOSPassword = true } else { model.showOSPassword = false; model.sheet = sheet } }
}

@available(iOS 17.0, *)
private struct NativeOpenSourceView: View {
    var body: some View {
        List {
            Section("Projects") {
                NavigationLink {
                    NativeLicenseText(title: "SwiftRust", resource: "SwiftRustNotice", additionalResources: ["AGPL-3.0"],
                        copyright: "© 2026 SwiftRust contributors.", license: "GNU AGPL v3")
                } label: { noticeRow("SwiftRust", "GNU AGPL v3") }
                .accessibilityIdentifier("native.swiftrustNotice")
                NavigationLink {
                    NativeLicenseText(title: "RustDesk", resource: "RustDeskNotice", additionalResources: ["AGPL-3.0"],
                        copyright: "Purslane Tech Pte. Ltd. and RustDesk contributors.", license: "GNU AGPL v3")
                } label: { noticeRow("RustDesk", "GNU AGPL v3") }
                .accessibilityIdentifier("native.agpl")
            }
            Section("Third-Party Software") {
                NavigationLink {
                    NativeLicenseText(title: "SwiftTerm", resource: "SwiftTermLicense",
                        copyright: "Miguel de Icaza and contributors. Original notices below.", license: "MIT License")
                } label: { noticeRow("SwiftTerm", "1.18.0 · MIT License") }
                NavigationLink {
                    NativeLicenseText(title: "Tailscale & libtailscale", resource: "TailscaleNotices",
                        copyright: "Tailscale Inc. and respective contributors.", license: "BSD-3-Clause and dependency licenses")
                } label: { noticeRow("Tailscale & libtailscale", "BSD-3-Clause and dependency licenses") }
                NavigationLink {
                    NativeLicenseText(title: "Dependency Notices", resource: "ThirdPartyNotices", additionalResources: ["TailscaleNotices"],
                        copyright: "Respective authors and contributors.", license: "As specified for each component")
                } label: { noticeRow("Dependency Notices", "Copyright and license texts") }
                .accessibilityIdentifier("native.licenseNotices")
            }
            Section("Corresponding Source") {
                if let repositoryURL = nativeRepositoryURL {
                    Link("SwiftRust Repository", destination: repositoryURL)
                }
                Link("RustDesk Repository", destination: URL(string: "https://github.com/rustdesk/rustdesk")!)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Open-Source Notices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func noticeRow(_ name: String, _ license: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.body).foregroundStyle(.primary)
            Text(license).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 7)
    }
}

@available(iOS 17.0, *)
private struct NativeLicenseText: View {
    let title: String
    let resource: String
    var additionalResources: [String] = []
    var copyright: String = "Respective authors and contributors."
    var license: String = "Original license text"
    @State private var chunks: [String] = []
    @State private var failed = false
    private var urls: [URL] { ([resource] + additionalResources).compactMap { Bundle.main.url(forResource: $0, withExtension: "txt") } }

    var body: some View {
        Group {
            if !chunks.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Copyright").font(.subheadline).foregroundStyle(.secondary)
                                Text(copyright).font(.body)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("License").font(.subheadline).foregroundStyle(.secondary)
                                Text(license).font(.body)
                            }
                        }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                        .padding(.bottom, 24)
                        ForEach(chunks.indices, id: \.self) { index in
                            Text(verbatim: chunks[index])
                                .font(.body).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(20)
                }
                .accessibilityIdentifier("native.licenseDocument")
            } else if failed {
                ContentUnavailableView("Unable to Open License", systemImage: "doc.text", description: Text("A license resource is missing."))
            } else { ProgressView("Loading…") }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(items: urls) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Export License")
            }
        }
        .task(id: resource) {
            let documents = urls
            guard documents.count == additionalResources.count + 1 else { failed = true; return }
            do {
                let contents = try await Task.detached(priority: .userInitiated) {
                    NativeNoticeDocument.pages(try documents.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n\n"))
                }.value
                try Task.checkCancellation()
                chunks = contents
            } catch is CancellationError { }
            catch { failed = true }
        }
    }
}

enum NativeNoticeDocument {
    static func pages(_ text: String) -> [String] {
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            var end = text.index(start, offsetBy: 16_000, limitedBy: text.endIndex) ?? text.endIndex
            if end < text.endIndex, let newline = text[start..<end].lastIndex(of: "\n") { end = text.index(after: newline) }
            result.append(String(text[start..<end]))
            start = end
        }
        return result
    }
}

@available(iOS 17.0, *)
struct NativeOSPasswordSettings: View {
    @ObservedObject var model: NativeShellModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var autoLogin = false
    @State private var session = ""
    @State private var editable = false
    @State private var error = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea().onTapGesture { close() }.accessibilityHidden(true)
            surface.padding(.horizontal, 24)
        }
        .environment(\.colorScheme, .dark).tint(nativeRustBlue)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            do {
                let value = try model.core.call("osPasswordSettings")
                session = value["session"] as? String ?? ""
                password = value["password"] as? String ?? ""
                autoLogin = value["autoLogin"] as? Bool ?? false
                editable = value["editable"] as? Bool ?? false
            } catch { self.error = error.localizedDescription }
        }
        .onDisappear { password = "" }
    }

    @ViewBuilder private var surface: some View {
        if #available(iOS 26.0, *) {
            controls.glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            controls.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(NativeL("自动登录")).font(.system(size: 20, weight: .semibold))
                Spacer()
                Button { close() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30).background(.white.opacity(0.1), in: Circle())
                }.accessibilityLabel(NativeL("取消"))
            }
            SecureField(NativeL("操作系统密码"), text: $password)
                .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(12).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("native.osPassword")
                .disabled(!editable || !model.connected)
            Toggle(NativeL("自动登录"), isOn: $autoLogin).tint(.green)
                .disabled(!editable || !model.connected)
            Text(NativeL("自动登录需要同时启用“结束会话后锁屏”。"))
                .font(.footnote).foregroundStyle(.white.opacity(0.65))
            if !error.isEmpty { Text(NativeL(error)).font(.footnote).foregroundStyle(.red) }
            Button(NativeL("保存设置")) { save() }
                .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                .background(nativeRustBlue, in: RoundedRectangle(cornerRadius: 12))
                .disabled(!editable || !model.connected || (autoLogin && password.isEmpty))
        }.font(.system(size: 18)).foregroundStyle(.white).buttonStyle(.plain)
            .padding(20).frame(maxWidth: 360)
    }
    private func close() {
        password = ""
        model.canvas?.hideSystemKeyboard()
        model.showOSPassword = false
        if model.sheet == .osPassword { model.sheet = nil } else { dismiss() }
    }

    private func save() {
        do {
            _ = try model.core.call("saveOSPassword", ["session": session, "password": password, "send": false, "autoLogin": autoLogin])
            close()
        } catch { self.error = error.localizedDescription }
    }
}

private struct NativeBrandLinkLabel: View {
    let title: String
    let image: String

    var body: some View {
        Label {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer(minLength: 12)
                Image(systemName: "arrow.up.right").font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }
        } icon: {
            Image(image).resizable().scaledToFit().frame(width: 20, height: 20)
                .foregroundStyle(.primary).accessibilityHidden(true)
        }
    }
}
