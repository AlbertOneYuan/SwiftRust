import XCTest
import SwiftUI
import Combine
import Network
@testable import Runner

@available(iOS 17.0, *)
@MainActor
final class NativeFrontendTests: XCTestCase {
    func testHomeQuickActionMenuKeepsThreeToolsAndCommonDeviceEntry() {
        let empty = NativeHomeQuickActions.items(devices: [])
        XCTAssertEqual(empty.map(\.type), [NativeHomeQuickActions.newWindow, NativeHomeQuickActions.scan, NativeHomeQuickActions.configure])
        let a = NativeQuickDevice(id: "work.local", name: "工作电脑", mode: "terminal", relay: true)
        let single = NativeHomeQuickActions.items(devices: [a])
        XCTAssertEqual(single.count, 4)
        XCTAssertEqual(single.first?.localizedTitle, "工作电脑")
        let multiple = NativeHomeQuickActions.items(devices: [a, NativeQuickDevice(id: "mini.local", name: "Mini")])
        XCTAssertEqual(multiple.count, 5)
        XCTAssertEqual(multiple.prefix(2).map(\.localizedTitle), ["工作电脑", "Mini"])
        XCTAssertEqual(multiple.prefix(2).map(\.type), [NativeHomeQuickActions.deviceAction(a), NativeHomeQuickActions.deviceAction(NativeQuickDevice(id: "mini.local", name: "Mini"))])
        let desktop = NativeQuickDevice(id: a.id, name: a.name)
        let sameDevice = NativeHomeQuickActions.items(devices: [a, desktop])
        XCTAssertNotEqual(sameDevice[0].type, sameDevice[1].type)
        XCTAssertNotEqual(sameDevice[0].localizedSubtitle, sameDevice[1].localizedSubtitle)
        XCTAssertTrue(a.link.newWindow)
        XCTAssertEqual(a.link.mode, .terminal)
        XCTAssertTrue(a.link.relay)
    }
    func testHomeQuickActionRoutesSettingsScannerAndCommonWithoutReplacingSession() async throws {
        let store = NativeQuickDevices.shared
        let old = store.devices
        let raw = UserDefaults.standard.object(forKey: NativeQuickDevices.storageKey)
        let model = NativeShellModel(window: UUID().uuidString)
        defer {
            model.closeSession(); store.save(old)
            UserDefaults.standard.set(raw, forKey: NativeQuickDevices.storageKey)
        }
        store.save([])
        _ = await NativeHomeQuickActions.perform(NativeHomeQuickActions.configure, model: model, inNewScene: true)
        XCTAssertEqual(model.sheet, .quickDeviceSettings)
        _ = await NativeHomeQuickActions.perform(NativeHomeQuickActions.scan, model: model, inNewScene: true)
        XCTAssertEqual(model.sheet, .scanner)
        let device = NativeQuickDevice(id: "127.0.0.1:9", name: "测试设备", mode: "files")
        model.sheet = nil
        store.save([device])
        let saved = try XCTUnwrap(UserDefaults.standard.data(forKey: NativeQuickDevices.storageKey))
        XCTAssertEqual(try JSONDecoder().decode([NativeQuickDevice].self, from: saved), [device])
        _ = await NativeHomeQuickActions.perform(NativeHomeQuickActions.deviceAction(device), model: model, inNewScene: true)
        XCTAssertEqual(model.remoteID, device.id)
        XCTAssertEqual(model.remoteKind, .files)
        let other = NativeQuickDevice(id: device.id, name: device.name, mode: "terminal")
        store.save([device, other])
        let second = NativeShellModel(window: UUID().uuidString)
        defer { second.closeSession() }
        _ = await NativeHomeQuickActions.perform(NativeHomeQuickActions.deviceAction(other), model: second, inNewScene: true)
        XCTAssertEqual(second.remoteID, other.id)
        XCTAssertEqual(second.remoteKind, .terminal)
        XCTAssertNotEqual(NativeHomeQuickActions.deviceAction(device), NativeHomeQuickActions.deviceAction(other))
        XCTAssertNil(second.sheet)
        XCTAssertEqual(model.remoteID, device.id)
        let handled = await NativeHomeQuickActions.perform("unknown", model: model, inNewScene: false)
        XCTAssertFalse(handled)
    }
    func testEmbeddedCursorMetadataHidesOverlayAndSurvivesPartialDisplayEvents() throws {
        for value: Any in [true, 1, "1", "true"] { XCTAssertTrue(NativeDisplay.cursorEmbedded(value)) }
        for value: Any in [false, 0, "0", "false"] { XCTAssertFalse(NativeDisplay.cursorEmbedded(value)) }
        let model = NativeShellModel()
        model.inputMode = "trackpad"; model.connected = true
        model.sessionToggles = ["show-remote-cursor": true]
        let canvas = NativeCanvasView(model: model)
        defer { canvas.stop(); model.closeSession() }
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        let displays = try JSONSerialization.data(withJSONObject: [["x": 0, "y": 0, "width": 1920, "height": 1080, "cursor_embedded": true]])
        model.handle(["name": "peer_info", "displays": String(decoding: displays, as: UTF8.self), "current_display": "0"])
        canvas.displayFrame(try cursor().image, display: 0)
        let pointer = try XCTUnwrap(canvas.layer.sublayers?.dropFirst().first)
        XCTAssertTrue(pointer.isHidden)
        model.handle(["name": "switch_display", "display": "0", "width": "1280", "height": "720"])
        XCTAssertTrue(model.displays[0].embeddedCursor)
        XCTAssertFalse(model.drawLocalCursor)
        model.handle(["name": "switch_display", "display": "0", "cursor_embedded": "0"])
        canvas.displayFrame(try cursor().image, display: 0)
        XCTAssertFalse(pointer.isHidden)
    }
    func testNativeConnectIntentUsesForegroundWindowWithoutBrowserHandoff() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        UIApplication.shared.requestSceneSessionActivation(scene.session, userActivity: nil, options: nil)
        for _ in 0..<30 {
            if scene.activationState == .foregroundActive { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let controller = try XCTUnwrap(scene.windows.first?.rootViewController as? NativeHostingController)
        let model = controller.rootView.model
        guard model.remoteID == nil else { throw XCTSkip("Requires an idle foreground test scene") }
        let oldID = model.idText
        defer { model.closeSession(); model.idText = oldID }
        let intent = NativeConnectDeviceIntent()
        intent.id = "127.0.0.1:9"; intent.mode = .terminal; intent.newWindow = false; intent.relay = false
        _ = try await intent.perform()
        XCTAssertEqual(model.remoteID, "127.0.0.1:9")
        XCTAssertEqual(model.remoteKind, .terminal)
        XCTAssertTrue(UIApplication.shared.connectedScenes.contains { $0 === scene })
    }
    func testSignedShortcutTemplatesAreBundledAndExportedWithoutModification() throws {
        for mode in [NativeSessionKind.desktop, .terminal, .files, .camera] {
          for relay in [false, true] { for window in [false, true] {
            let source = try XCTUnwrap(Bundle.main.url(forResource: "SwiftRust-\(mode.rawValue)-r\(relay ? 1 : 0)w\(window ? 1 : 0)", withExtension: "shortcut", subdirectory: "ShortcutTemplates"))
            let signed = try Data(contentsOf: source)
            XCTAssertTrue(signed.count > 1000)
            XCTAssertEqual(String(decoding: signed.prefix(4), as: UTF8.self), "AEA1")
            let exported = try NativeShortcutTemplates.export(mode: mode, relay: relay, newWindow: window, name: "Work/Mac\\电脑")
            defer { try? FileManager.default.removeItem(at: exported.deletingLastPathComponent()) }
            XCTAssertEqual(try Data(contentsOf: exported), signed, "Changing signed template bytes invalidates import")
            XCTAssertEqual(exported.lastPathComponent, "WorkMac电脑.shortcut")
          } }
        }
    }
    func testGroupedNumericRemoteIDsConnectWithoutSpaces() throws {
        for id in ["1 694 351 955", " 1\u{00a0}694\u{202f}351 955 "] {
            XCTAssertEqual(NativeLaunchLink.normalizedID(id), "1694351955")
            XCTAssertEqual(NativeLaunchLink(id: id).id, "1694351955")
            var parts = URLComponents(string: "swiftrust://connect")!
            parts.queryItems = [URLQueryItem(name: "id", value: id)]
            XCTAssertEqual(try NativeLaunchLink(url: XCTUnwrap(parts.url)).id, "1694351955")
        }
        XCTAssertEqual(NativeLaunchLink.normalizedID(" [::1]:21118 "), "[::1]:21118")
        XCTAssertEqual(NativeLaunchLink.normalizedID("my host:21118"), "my host:21118")
    }
    func testLaunchLinksRoundTripAndRejectUnsafeParameters() throws {
        for mode in [NativeSessionKind.desktop, .terminal, .files, .camera] {
            var link = NativeLaunchLink(id: "[fd7a:115c:a1e0::1]:21118", mode: mode)
            link.relay = true; link.approval = true; link.newWindow = true; link.connect = false
            XCTAssertEqual(try NativeLaunchLink(url: link.url), link)
        }
        for raw in ["swiftrust://connect", "swiftrust://connect?id=a&id=b", "swiftrust://connect?id=a&password=secret", "swiftrust://connect?id=a&mode=unknown", "swiftrust://connect?id=a&relay=maybe", "swiftrust://delete?id=a", "swiftrust://connect?id=a%0Ab", "swiftrust://user:secret@connect?id=a"] {
            XCTAssertThrowsError(try NativeLaunchLink(url: XCTUnwrap(URL(string: raw))))
        }
    }
    func testQuickPasswordSendWithoutSavedPasswordDoesNotOpenEditor() async throws {
        let model = NativeShellModel(window: UUID().uuidString)
        defer { model.closeSession() }
        await model.connect(to: "127.0.0.10:9", kind: .desktop)
        let settings = try model.core.call("osPasswordSettings")
        XCTAssertEqual(settings["password"] as? String, "")
        model.sendSavedOSPassword()
        XCTAssertFalse(model.showOSPassword)
        XCTAssertEqual(model.errorMessage, "请先在自动登录中设置操作系统密码")
        model.closeSession()
        XCTAssertFalse(model.showOSPassword)
    }

    func testOSPasswordSettingsRejectStaleSessionAndUnauthorizedSend() async throws {
        let model = NativeShellModel(window: UUID().uuidString)
        defer { model.closeSession() }
        await model.connect(to: "127.0.0.8:9", kind: .desktop)
        let state = try model.core.call("osPasswordSettings")
        let session = try XCTUnwrap(state["session"] as? String)
        let password = state["password"] as? String ?? ""
        let autoLogin = state["autoLogin"] as? Bool ?? false
        XCTAssertThrowsError(try model.core.call("saveOSPassword", ["session": UUID().uuidString, "password": "test", "autoLogin": true, "send": false]))
        XCTAssertThrowsError(try model.core.call("saveOSPassword", ["session": session, "password": "", "autoLogin": true, "send": true]))
        let unchanged = try model.core.call("osPasswordSettings")
        XCTAssertEqual(unchanged["password"] as? String, password)
        XCTAssertEqual(unchanged["autoLogin"] as? Bool, autoLogin)
    }

    func testWindowChannelsKeepConnectionsAndDisconnectIndependent() async throws {
        let oldReconnect = UserDefaults.standard.object(forKey: "native.foreground-reconnect")
        let oldLast = UserDefaults.standard.object(forKey: "native.last-session")
        defer {
            UserDefaults.standard.set(oldReconnect, forKey: "native.foreground-reconnect")
            UserDefaults.standard.set(oldLast, forKey: "native.last-session")
        }
        let first = NativeShellModel(window: UUID().uuidString)
        let second = NativeShellModel(window: UUID().uuidString)
        defer { first.closeSession(); second.closeSession() }
        await first.connect(to: "127.0.0.1:9", kind: .terminal)
        await second.connect(to: "127.0.0.2:9", kind: .files)
        XCTAssertEqual(first.remoteKind, .terminal); XCTAssertEqual(second.remoteKind, .files)
        XCTAssertNotNil(first.remoteID); XCTAssertNotNil(second.remoteID)
        let a = try XCTUnwrap(first.core.call("poll")["session"] as? String)
        let b = try XCTUnwrap(second.core.call("poll")["session"] as? String)
        XCTAssertNotEqual(a, b)
        XCTAssertThrowsError(try first.core.call("resolution", ["session": b, "display": 0, "width": 1280, "height": 720]))
        first.firstFrame(); second.firstFrame()
        first.prepareForBackground()
        first.closeSession(preservingBackgroundSession: true)
        UserDefaults.standard.set(true, forKey: "native.foreground-reconnect")
        await first.reconnectOnForeground()
        XCTAssertEqual(first.remoteID, "127.0.0.1:9")
        XCTAssertEqual(first.remoteKind, .terminal, "Background recovery must not use the other window's last connection")
        XCTAssertEqual(try second.core.call("poll")["session"] as? String, b)
        XCTAssertEqual(second.remoteID, "127.0.0.2:9")
        let link = NativeLaunchLink(id: "third.local", mode: .desktop)
        await second.openLaunchLink(link)
        XCTAssertEqual(second.remoteID, "127.0.0.2:9", "An external link must not replace an existing session")
        XCTAssertNotNil(second.errorMessage)
    }
    func testProxyDraftStaysInKeychainWhenCoreProxyIsDisabled() throws {
        let previous = try NativeSavedProxy.load()
        let core = try NativeRustCore.call("loadProxy")["proxy"] as? [String] ?? []
        defer {
            try? (previous ?? NativeSavedProxy(address: "", username: "", password: "")).save()
            _ = try? NativeRustCore.call("saveProxy", ["proxy": core.first ?? "", "username": core.count > 1 ? core[1] : "", "password": core.count > 2 ? core[2] : ""])
        }
        let draft = NativeSavedProxy(address: "https://proxy.example.invalid:443", username: "proxy-test", password: "not-a-real-secret")
        try draft.save()
        _ = try NativeRustCore.call("saveProxy", ["proxy": "", "username": "", "password": ""])
        XCTAssertEqual(try NativeRustCore.call("loadProxy")["proxy"] as? [String], [])
        XCTAssertEqual(try NativeSavedProxy.load(), draft)
    }
    func testAuthKeyInputAcceptsAuthKeysAndRejectsOtherCredentials() {
        XCTAssertTrue(NativeTailscaleController.validAuthKey(" tskey-auth-unit-test-not-real "))
        for key in ["", "tskey-auth-", "tskey-api-not-an-auth-key", "tskey-client-not-an-auth-key", "tskey-auth-has whitespace"] {
            XCTAssertFalse(NativeTailscaleController.validAuthKey(key))
        }
    }
    func testProductBrandingPreservesOnlyAttribution() {
        XCTAssertEqual(NativeL("RustDesk"), "SwiftRust")
        XCTAssertEqual(NativeL("rustdesk"), "SwiftRust")
        XCTAssertEqual(NativeL("RustDesk", preserveAttribution: true), "RustDesk")
    }
    func testLicensePagesPreserveEntireDocumentAndUnicode() {
        let document = String(repeating: "版权 © SwiftRust 🦀\n", count: 4000) + "Last notice, no trailing newline"
        let pages = NativeNoticeDocument.pages(document)
        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertTrue(pages.allSatisfy { $0.count <= 16_000 })
        XCTAssertEqual(pages.joined(), document)
    }
    func testLanguageSelectionUsesOriginalTranslationsAndSystemFallback() {
        let store = NativeTranslationStore.shared
        XCTAssertEqual(store.languages.filter { $0[0] == "en" }.count, 1)
        XCTAssertEqual(store.lookup("设置", language: "en"), "Settings")
        XCTAssertEqual(store.lookup("设置", language: "zh-cn"), "设置")
        XCTAssertEqual(store.lookup("device-name-not-a-ui-string", language: "en"), "device-name-not-a-ui-string")
        let supported = ["en", "fr", "zh-cn", "zh-tw", "pt-br", "pt-pt"]
        XCTAssertEqual(NativeTranslationStore.resolve("", preferred: ["zh-Hant-HK"], available: supported), "zh-tw")
        XCTAssertEqual(NativeTranslationStore.resolve("", preferred: ["fr-CA"], available: supported), "fr")
        XCTAssertEqual(NativeTranslationStore.resolve("en", preferred: ["zh-CN"], available: supported), "en")
    }
    func testAppleTranslationKeepsFormattingArgumentsAndRejectsBrokenResults() {
        XCTAssertTrue(NativeTranslationStore.validTranslation(source: "当前 %@ × %@", target: "Current %@ × %@"))
        XCTAssertFalse(NativeTranslationStore.validTranslation(source: "当前 %@ × %@", target: "Current %@"))
        XCTAssertFalse(NativeTranslationStore.validTranslation(source: "设置", target: "  "))
    }
    private func cursor() throws -> NativeCursor {
        let data = Data([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255])
        return try XCTUnwrap(NativeRustCore.cursor(["width": 2, "height": 2, "hotx": 1, "hoty": 1, "colors": data.base64EncodedString()]))
    }
    func testConnectionMessagesClearDisconnectedVideoAndRespectRetryFlag() throws {
        let model = NativeShellModel()
        model.remoteID = "native-regression-peer"
        let key = "native.skip-prompt.reconnect.native-regression-peer"
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key); model.closeSession() }
        let canvas = NativeCanvasView(model: model)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        canvas.displayFrame(try cursor().image, display: 0)
        model.handle(["name": "msgbox", "type": "success", "text": "完成"])
        XCTAssertTrue(model.connected)
        XCTAssertNil(model.prompt)
        XCTAssertNotNil(model.lastFrame)
        model.handle(["name": "msgbox", "type": "error", "title": "连接错误", "text": "远端离线", "hasRetry": "", "sourceTitle": "Connection Error"])
        XCTAssertFalse(try XCTUnwrap(model.prompt).hasRetry)
        XCTAssertNil(model.lastFrame)
        canvas.displayFrame(try cursor().image, display: 0)
        XCTAssertNil(model.lastFrame)
        XCTAssertFalse(model.connected)
        model.continuePrompt(try XCTUnwrap(model.prompt), skip: false)
        XCTAssertNil(model.prompt)
        XCTAssertFalse(model.connected)
        UserDefaults.standard.set(true, forKey: key)
        model.handle(["name": "msgbox", "type": "error", "title": "连接错误", "hasRetry": "true"])
        model.handle(["name": "msgbox", "type": "error", "title": "连接错误", "hasRetry": "true"])
        XCTAssertNil(model.prompt)
        XCTAssertNotEqual(model.sheet, .connectionPrompt)
        XCTAssertTrue(try XCTUnwrap(model.connectionFailure).hasRetry)
        model.continuePrompt(try XCTUnwrap(model.connectionFailure), skip: false)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
        canvas.stop()
    }
    func testConnectionMetricsRefreshWithoutInvalidatingControlMenus() {
        let model = NativeShellModel()
        var shellChanges = 0
        var metricChanges = 0
        let shell = model.objectWillChange.sink { shellChanges += 1 }
        let metrics = model.connectionMetrics.objectWillChange.sink { metricChanges += 1 }
        model.handle(["name": "update_quality_status", "delay": "14"])
        model.handle(["name": "update_quality_status", "delay": "15"])
        XCTAssertEqual(model.connectionStats["delay"], "15")
        XCTAssertEqual(metricChanges, 2)
        XCTAssertEqual(shellChanges, 0)
        withExtendedLifetime((shell, metrics)) {}
    }
    func testOriginalTwoFingerGesturesPanWhileNewModesScroll() {
        var original = NativeTwoFingerGesture(), modern = NativeTwoFingerGesture()
        original.begin(first: CGPoint(x: 100, y: 100), second: CGPoint(x: 200, y: 100))
        modern.begin(first: CGPoint(x: 100, y: 100), second: CGPoint(x: 200, y: 100))
        let a = CGPoint(x: 100, y: 120), b = CGPoint(x: 200, y: 120)
        XCTAssertEqual(original.move(first: a, second: b, canvasOnly: true), .transform(1, CGPoint(x: 150, y: 100), CGPoint(x: 150, y: 120)))
        XCTAssertEqual(modern.move(first: a, second: b), .scroll(CGPoint(x: 0, y: 20)))
        original.end()
        original.begin(first: CGPoint(x: 100, y: 100), second: CGPoint(x: 200, y: 100))
        XCTAssertEqual(original.move(first: CGPoint(x: 125, y: 100), second: CGPoint(x: 225, y: 100), canvasOnly: true), .transform(1, CGPoint(x: 150, y: 100), CGPoint(x: 175, y: 100)))
    }
    func testTailscaleRoutesOnlyTailnetAddressesAndDiscoveredNames() throws {
        for target in ["100.64.0.1", "100.127.255.254:21118", "host.example.ts.net:21118", "[fd7a:115c:a1e0::1]:21118"] {
            XCTAssertTrue(NativeTailscaleController.isTailnetTarget(target), target)
        }
        for target in ["100.63.255.255", "100.128.0.1", "100.64.999.1", "100.64.bad.1.2", "192.168.1.1", "160111967", "example.com:443", ":"] {
            XCTAssertFalse(NativeTailscaleController.isTailnetTarget(target), target)
        }
        let peer = try JSONDecoder().decode(NativeTailnetPeer.self, from: Data(#"{"DNSName":"office.example.ts.net.","HostName":"office","TailscaleIPs":["100.64.0.2"],"Online":true}"#.utf8))
        XCTAssertTrue(NativeTailscaleController.isTailnetTarget("office:21118", peers: [peer]))
        XCTAssertEqual(peer.host, "office.example.ts.net")
    }
    func testEmbeddedTailscaleStartsAndProvidesAuthenticatedLoopbackWithoutVPN() async throws {
        let node = tailscale_new()
        XCTAssertGreaterThan(node, 0)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { _ = SwiftRustTSClose(node); try? FileManager.default.removeItem(at: directory) }
        var output: UnsafeMutablePointer<CChar>?
        XCTAssertEqual(SwiftRustTSAction(node, "configure", &output), 0)
        if let output { free(output) }
        XCTAssertEqual(tailscale_set_dir(node, directory.path), 0)
        XCTAssertEqual(tailscale_set_hostname(node, "swiftrust-simulator-check"), 0)
        XCTAssertEqual(tailscale_set_ephemeral(node, 1), 0)
        XCTAssertEqual(tailscale_start(node), 0)
        output = nil
        XCTAssertEqual(tailscale_status_json(node, &output), 0)
        let statusPointer = try XCTUnwrap(output)
        let statusData = Data(String(cString: statusPointer).utf8); free(statusPointer)
        XCTAssertFalse(try JSONDecoder().decode(NativeTailnetStatus.self, from: statusData).BackendState.isEmpty)
        output = nil
        XCTAssertEqual(SwiftRustTSAction(node, "proxy", &output), 0)
        let proxyPointer = try XCTUnwrap(output)
        let proxyData = Data(String(cString: proxyPointer).utf8); free(proxyPointer)
        let proxy = try XCTUnwrap(JSONSerialization.jsonObject(with: proxyData) as? [String:String])
        XCTAssertEqual(proxy["username"], "swiftrust")
        XCTAssertFalse(try XCTUnwrap(proxy["password"]).isEmpty)
        let endpoint = try NativeProxyEndpoint.parse(try XCTUnwrap(proxy["address"]), kind: .socks5)
        XCTAssertEqual(endpoint.host, "127.0.0.1")
        let connection = NWConnection(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: endpoint.port)), using: .tcp)
        let authenticatedOnly = expectation(description: "Embedded SOCKS requires username/password")
        connection.stateUpdateHandler = { state in
            guard case .ready = state else { return }
            connection.send(content: Data([5,1,2]), completion: .contentProcessed { _ in
                connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, error in
                    XCTAssertEqual(data, Data([5,2])); XCTAssertNil(error); authenticatedOnly.fulfill()
                }
            })
        }
        connection.start(queue: .global())
        defer { connection.cancel() }
        await fulfillment(of: [authenticatedOnly], timeout: 5)
    }
    func testProxyAddressesNormalizeWithoutLosingProtocolOrPort() throws {
        let examples: [(String, NativeProxyEndpoint.Kind, String)] = [
            ("proxy.example.com:7890", .http, "http://proxy.example.com:7890"),
            ("192.0.2.1:1080", .socks5, "socks5://192.0.2.1:1080"),
            ("[2001:db8::1]:443", .https, "https://[2001:db8::1]:443"),
            (" HTTPS://proxy.example.com:443/ ", .socks5, "https://proxy.example.com:443"),
            ("socks://proxy.example.com:1080/", .http, "socks5://proxy.example.com:1080"),
            ("https://proxy.example.com", .socks5, "https://proxy.example.com:443")
        ]
        for (input, kind, expected) in examples { XCTAssertEqual(try NativeProxyEndpoint.parse(input, kind: kind).url, expected) }
        for invalid in ["proxy.example.com", "host:0", "host:65536", "host:abc", "ftp://host:21", "http://user:secret@host:80", "http://host:80/path", "http://host:80?key=x"] {
            XCTAssertThrowsError(try NativeProxyEndpoint.parse(invalid, kind: .socks5), invalid)
        }
    }
    func testProxyLatencyMeasuresRealTCPConnectionAndClearsOnEdit() async throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        let listener = try NWListener(using: parameters, on: .any)
        let ready = expectation(description: "Loopback TCP listener ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { $0.cancel() }
        listener.start(queue: .global())
        defer { listener.cancel() }
        await fulfillment(of: [ready], timeout: 5)
        let port = try XCTUnwrap(listener.port)
        let endpoint = try NativeProxyEndpoint.parse("127.0.0.1:\(port.rawValue)", kind: .http)
        let probe = NativeProxyProbe(); probe.start(endpoint)
        for _ in 0..<100 {
            if !probe.testing { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotNil(probe.milliseconds)
        XCTAssertNil(probe.error)
        probe.reset()
        XCTAssertNil(probe.milliseconds)
        XCTAssertFalse(probe.testing)
    }
    func testOpenSourceLicenseResourcesAreBundled() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SwiftRustRepositoryURL") as? String, "https://github.com/AlbertOneYuan/SwiftRust")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SwiftRustSourceURL") as? String, "")
        for (name, expected) in [("AGPL-3.0", "GNU AFFERO GENERAL PUBLIC LICENSE"),
                                 ("ThirdPartyNotices", "SwiftTerm 1.18.0"),
                                 ("SwiftTermLicense", "Permission is hereby granted")] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "txt"))
            XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains(expected))
        }
    }
    func testLaunchRestoreIsIndependentFromBackgroundReconnect() async {
        let keys = ["native.launch-restore", "native.foreground-reconnect", "native.last-session"]
        let old = keys.map { UserDefaults.standard.object(forKey: $0) }
        let model = NativeShellModel()
        defer {
            model.closeSession()
            for (key, value) in zip(keys, old) { UserDefaults.standard.set(value, forKey: key) }
        }
        UserDefaults.standard.set(["id": "127.0.0.1:9", "mode": "terminal"], forKey: keys[2])
        UserDefaults.standard.set(false, forKey: keys[0])
        UserDefaults.standard.set(true, forKey: keys[1])
        await model.restoreOnLaunch()
        XCTAssertNil(model.remoteID)
        UserDefaults.standard.set(true, forKey: keys[0])
        UserDefaults.standard.set(false, forKey: keys[1])
        await model.restoreOnLaunch()
        XCTAssertEqual(model.remoteKind, .terminal)
        XCTAssertEqual(model.remoteID, "127.0.0.1:9")
        model.firstFrame()
        await model.restoreOnLaunch()
        XCTAssertTrue(model.connected)
        model.closeSession()
        await model.reconnectOnForeground()
        XCTAssertNil(model.remoteID)
    }
    func testForegroundReconnectRestoresLastSessionKindOnlyWhenEnabled() async throws {
        let key = "native.foreground-reconnect"
        let previous = UserDefaults.standard.object(forKey: key)
        let savedLast = UserDefaults.standard.object(forKey: "native.last-session")
        let model = NativeShellModel()
        defer {
            model.closeSession()
            UserDefaults.standard.set(previous, forKey: key)
            UserDefaults.standard.set(savedLast, forKey: "native.last-session")
        }
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.set(["id": "127.0.0.1:9", "mode": "desktop"], forKey: "native.last-session")
        model.prepareForBackground()
        await model.reconnectOnForeground()
        XCTAssertNil(model.remoteID, "Returning from Home must not restore connection history")
        for kind in [NativeSessionKind.desktop, .terminal, .files, .camera] {
            await model.connect(to: "127.0.0.1:9", kind: kind)
            model.firstFrame()
            model.prepareForBackground()
            model.closeSession(preservingBackgroundSession: true)
            await model.reconnectOnForeground()
            XCTAssertEqual(model.remoteID, "127.0.0.1:9")
            XCTAssertEqual(model.remoteKind, kind)
            model.firstFrame()
            model.prepareForBackground()
            await model.reconnectOnForeground()
            XCTAssertTrue(model.connected, "A healthy connection must remain untouched")
            model.prepareForBackground()
            model.handle(["name": "msgbox", "type": "error", "sourceTitle": "Connection Error", "text": "连接超时", "hasRetry": "true"])
            await model.reconnectOnForeground()
            XCTAssertNil(model.connectionFailure)
            model.firstFrame()
            model.prepareForBackground()
            model.closeSession()
            await model.reconnectOnForeground()
            XCTAssertNil(model.remoteID, "Explicit disconnect cancels automatic recovery")
        }
        await model.connect(to: "127.0.0.1:9")
        model.firstFrame(); model.prepareForBackground()
        model.closeSession(preservingBackgroundSession: true)
        UserDefaults.standard.set(false, forKey: key)
        await model.reconnectOnForeground()
        XCTAssertNil(model.remoteID)
        UserDefaults.standard.set(true, forKey: key)
        await model.reconnectOnForeground()
        XCTAssertNil(model.remoteID, "Background recovery is consumed once, not remembered forever")
    }
    func testDisconnectConfirmationCanBeDisabledAndRestored() {
        let key = "native.skip-disconnect-confirmation"
        let original = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(original, forKey: key) }
        let model = NativeShellModel()
        model.remoteID = "confirmation-test"
        UserDefaults.standard.set(false, forKey: key)
        model.requestDisconnect()
        XCTAssertTrue(model.confirmDisconnect)
        XCTAssertNotNil(model.remoteID)
        UserDefaults.standard.set(true, forKey: key)
        model.requestDisconnect()
        XCTAssertFalse(model.confirmDisconnect)
        XCTAssertNil(model.remoteID)
        UserDefaults.standard.set(false, forKey: key)
        model.remoteID = "confirmation-test"
        model.requestDisconnect()
        XCTAssertTrue(model.confirmDisconnect)
        model.closeSession()
    }
    func testRemoteCursorDefaultsOnAndRespectsSavedAndSessionChoices() {
        let key = "native.show-remote-cursor"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        let model = NativeShellModel()
        XCTAssertTrue(model.sessionToggle("show-remote-cursor"))
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(model.sessionToggle("show-remote-cursor"))
        model.apply(["sessionSettings": ["toggles": ["show-remote-cursor": true]]])
        XCTAssertTrue(model.sessionToggle("show-remote-cursor"))
    }
    func testStatisticsUseDecodedImageSizeSeparatelyFromHiDPIDesktopMode() throws {
        let model = NativeShellModel()
        model.handle(["name": "peer_info", "current_display": "0", "displays": "[{\"width\":3200,\"height\":2400,\"scaled_width\":1600}]"])
        let canvas = NativeCanvasView(model: model)
        canvas.displayFrame(try cursor().image, display: 0)
        XCTAssertEqual(model.currentResolution, NativeResolution(width: 1600, height: 1200))
        XCTAssertEqual(model.connectionMetrics.frameResolution, NativeResolution(width: 2, height: 2))
        canvas.prepareDisplay()
        XCTAssertNil(model.connectionMetrics.frameResolution)
        model.closeSession()
    }
    func testStatisticsDoNotReuseAnotherDisplaysFPSOrMixRateUnits() {
        let model = NativeShellModel()
        model.handle(["name": "update_quality_status", "fps": "{\"0\":60}", "speed": "1024.00kB/s", "delay": "14", "target_bitrate": "8000"])
        XCTAssertEqual(model.connectionMetrics.receiveRate, "1024.00 KiB/s")
        model.displayIndex = 1
        XCTAssertNil(model.connectionStats["fps"])
        model.handle(["name": "update_quality_status", "fps": "{\"0\":59}", "delay": "-2", "target_bitrate": "invalid"])
        XCTAssertNil(model.connectionStats["fps"])
        XCTAssertEqual(model.connectionStats["delay"], "14")
        XCTAssertEqual(model.connectionStats["target_bitrate"], "8000")
        model.handle(["name": "update_quality_status", "fps": "{\"1\":0}", "delay": "0", "target_bitrate": "0"])
        XCTAssertEqual(model.connectionStats["fps"], "0")
        XCTAssertEqual(model.connectionStats["delay"], "0")
    }
    func testConnectionStatisticsMergePartialUpdatesAndClearOnClose() {
        let key = "native.default-canvas-lock"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.set(true, forKey: key)
        let model = NativeShellModel()
        XCTAssertTrue(model.canvasLocked)
        model.handle(["name": "update_quality_status", "speed": "2.5 MB/s", "fps": "{\"0\":60,\"1\":30}", "delay": "14", "codec_format": "H264", "target_bitrate": "8000"])
        XCTAssertEqual(model.connectionStats["fps"], "60")
        XCTAssertEqual(model.connectionStats["speed"], "2.5 MB/s")
        model.handle(["name": "update_quality_status", "fps": "{}", "delay": "15", "target_bitrate": "8001"])
        XCTAssertEqual(model.connectionStats["fps"], "60")
        XCTAssertEqual(model.connectionStats["speed"], "2.5 MB/s")
        model.displayIndex = 1
        model.handle(["name": "update_quality_status", "speed": "", "fps": "{\"1\":28}", "delay": "18"])
        XCTAssertEqual(model.connectionStats["fps"], "28")
        XCTAssertEqual(model.connectionStats["speed"], "2.5 MB/s")
        XCTAssertEqual(model.connectionStats["delay"], "18")
        model.closeSession()
        XCTAssertTrue(model.connectionStats.isEmpty)
    }
    func testLargeRemoteDirectoryLoadsAsynchronouslyWithNaturalOrder() async throws {
        let files = NativeFileModel()
        defer { files.reset() }
        var rows: [[String: Any]] = (1...10000).reversed().map { ["name": "file\($0).txt", "entry_type": 4, "size": $0] }
        rows.append(["name": "Folder", "entry_type": 0]); rows.append(["name": ".", "entry_type": 0])
        let data = try JSONSerialization.data(withJSONObject: ["path": "/Remote", "entries": rows])
        let event: [String: Any] = ["name": "file_dir", "is_local": "false", "value": String(decoding: data, as: UTF8.self)]
        files.loading = true
        files.handle(event)
        XCTAssertTrue(files.loading)
        XCTAssertTrue(files.entries.isEmpty, "Directory sorting must yield the UI thread")
        files.reset()
        files.loading = true
        files.handle(event)
        for _ in 0..<500 { if !files.loading { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(files.loading)
        XCTAssertEqual(files.path, "/Remote")
        XCTAssertEqual(files.entries.count, 10001)
        XCTAssertEqual(Array(files.entries.prefix(3)).map(\.name), ["Folder", "file1.txt", "file2.txt"])
    }
    func testUploadPickerUsesNativePresentationWithinWindow() async throws {
        let host = UIHostingController(rootView: NativeUploadPresenter(isPresented: .constant(false)) { _ in })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { host.dismiss(animated: false); window.isHidden = true; window.rootViewController = nil }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        host.rootView = NativeUploadPresenter(isPresented: .constant(true)) { _ in }
        func picker(in controller: UIViewController) -> UIDocumentPickerViewController? {
            if let value = controller as? UIDocumentPickerViewController { return value }
            if let presented = controller.presentedViewController, let value = picker(in: presented) { return value }
            return controller.children.compactMap { picker(in: $0) }.first
        }
        for _ in 0..<1500 { if picker(in: host)?.viewIfLoaded?.window != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        let documentPicker = try XCTUnwrap(picker(in: host))
        let pickerWindow = try XCTUnwrap(documentPicker.view.window)
        let frame = documentPicker.view.convert(documentPicker.view.bounds, to: pickerWindow)
        XCTAssertLessThanOrEqual(frame.width, pickerWindow.bounds.width + 1)
        XCTAssertLessThanOrEqual(frame.height, pickerWindow.bounds.height + 1)
        XCTAssertFalse(documentPicker.allowsMultipleSelection)
        XCTAssertNotNil(documentPicker.presentingViewController)
    }

    func testUploadPreparationYieldsAndCancellationDoesNotStartTransfer() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(repeating: 42, count: 1024 * 1024).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let local = try await Task.detached { try NativeUploadPreparation.copy(source) }.value
        defer { try? FileManager.default.removeItem(at: local.deletingLastPathComponent()) }
        XCTAssertEqual(try Data(contentsOf: local), try Data(contentsOf: source))
        let files = NativeFileModel()
        defer { files.reset() }
        files.upload(source)
        XCTAssertTrue(files.transferring)
        XCTAssertEqual(files.status, "正在准备上传…")
        files.cancel()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(files.transferring)
        XCTAssertEqual(files.status, "传输已取消")
        files.upload(source.appendingPathComponent("missing"))
        for _ in 0..<200 { if !files.transferring { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(files.transferring)
        XCTAssertNotEqual(files.status, "正在准备上传…")
    }

    func testDownloadJobListingDoesNotReplaceRemoteDirectory() async throws {
        let files = NativeFileModel()
        files.path = "/Remote"; files.entries = [NativeRemoteFile(name: "photo.png", size: 2048, directory: false)]
        defer { files.reset() }
        let value = "{\"id\":1,\"path\":\"/Remote/photo.png\",\"entries\":[{\"name\":\"\",\"entry_type\":4,\"size\":2048}]}"
        files.handle(["name": "file_dir", "is_local": "false", "value": value])
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(files.path, "/Remote")
        XCTAssertEqual(files.entries.map(\.name), ["photo.png"])
        XCTAssertFalse(files.loading)
    }

    func testDownloadManagerKeepsCompletedFilesAndExcludesPartialFiles() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads")
        let folder = root.appendingPathComponent(UUID().uuidString)
        let partial = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder); try? FileManager.default.removeItem(at: partial) }
        let complete = folder.appendingPathComponent("sample.txt")
        let incomplete = partial.appendingPathComponent("partial.txt")
        try Data("complete".utf8).write(to: complete)
        let source = NativeDownloadSource(peer: "test-peer", path: "/Remote/sample.txt", size: 8, modified: 123)
        try JSONEncoder().encode(source).write(to: folder.appendingPathComponent(NativeDownloadSource.metadataName))
        try Data("partial".utf8).write(to: incomplete)
        try Data().write(to: partial.appendingPathComponent(".swiftrust-incomplete"))
        let files = NativeFileModel()
        await files.reloadDownloads()
        XCTAssertTrue(files.downloads.contains { $0.url == complete && $0.size == 8 })
        XCTAssertFalse(files.downloads.contains { $0.url == incomplete })
        XCTAssertFalse(files.downloads.contains { $0.url.lastPathComponent == NativeDownloadSource.metadataName })
        files.path = "/Remote"
        files.download(NativeRemoteFile(name: "sample.txt", size: 8, directory: false, modified: 123), peer: "test-peer")
        for _ in 0..<200 { if !files.transferring { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(files.transferring)
        XCTAssertEqual(files.downloadedURL, complete)
        XCTAssertEqual(files.status, "文件已下载，无需重复下载")
        files.reset()
        await files.reloadDownloads()
        XCTAssertTrue(files.downloads.contains { $0.url == complete })
        files.deleteDownload(try XCTUnwrap(files.downloads.first { $0.url == complete }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: complete.path))
    }

    func testBatchDownloadKeepsSelectedPathsAndReusesCompletedItems() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads")
        var folders: [URL] = []
        defer { for folder in folders { try? FileManager.default.removeItem(at: folder) } }
        var localFiles: [URL] = []
        for name in ["one.txt", "two.txt"] {
            let folder = root.appendingPathComponent(UUID().uuidString)
            folders.append(folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(name)
            try Data("data".utf8).write(to: url)
            let source = NativeDownloadSource(peer: "batch-peer", path: "/Selected/" + name, size: 4, modified: 123)
            try JSONEncoder().encode(source).write(to: folder.appendingPathComponent(NativeDownloadSource.metadataName))
            localFiles.append(url)
        }
        let files = NativeFileModel()
        defer { files.reset() }
        files.path = "/Selected"
        files.download(["one.txt", "two.txt"].map { NativeRemoteFile(name: $0, size: 4, directory: false, modified: 123) }, peer: "batch-peer")
        files.path = "/Other"
        for _ in 0..<300 { if !files.transferring && files.pendingDownloads.isEmpty { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(files.downloadedURL, localFiles.last)
        XCTAssertTrue(files.pendingDownloads.isEmpty)
        XCTAssertEqual(files.status, "文件已下载，无需重复下载")
        let folder = root.appendingPathComponent(UUID().uuidString)
        folders.append(folder)
        let directory = folder.appendingPathComponent("Nested")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: directory.appendingPathComponent("file.txt"))
        let source = NativeDownloadSource(peer: "batch-peer", path: "/Selected/Nested", size: 0, modified: 123, directory: true)
        try JSONEncoder().encode(source).write(to: folder.appendingPathComponent(NativeDownloadSource.metadataName))
        await files.reloadDownloads()
        XCTAssertTrue(files.downloads.contains { $0.url.path == directory.path && $0.directory })
        files.cancel()
        XCTAssertTrue(files.pendingDownloads.isEmpty)
    }

    func testEmptyDownloadDirectoriesPreserveStructureAndRejectTraversal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let response = "{\"path\":\"/Remote/Folder\",\"empty_dirs\":[{\"path\":\"/Remote/Folder/Nested/Empty\",\"entries\":[]}]}"
        XCTAssertTrue(try NativeEmptyDownloadFolders.create(response, remoteRoot: "/Remote/Folder", localRoot: root))
        var directory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Nested/Empty").path, isDirectory: &directory))
        XCTAssertTrue(directory.boolValue)
        XCTAssertFalse(try NativeEmptyDownloadFolders.create(response, remoteRoot: "/Other", localRoot: root))
        let invalid = "{\"path\":\"/Remote/Folder\",\"empty_dirs\":[{\"path\":\"/Remote/Folder/../Escape\",\"entries\":[]}]}"
        XCTAssertThrowsError(try NativeEmptyDownloadFolders.create(invalid, remoteRoot: "/Remote/Folder", localRoot: root))
    }

    func testPermanentDeletionRequiresConfirmationAndCurrentSession() async throws {
        let model = NativeShellModel(window: UUID().uuidString)
        defer { model.closeSession() }
        await model.connect(to: "127.0.0.11:9", kind: .files)
        let session = try XCTUnwrap(model.currentSessionID)
        let args: [String: Any] = ["session": session, "job": 1, "operation": "file", "path": "/test.txt"]
        XCTAssertThrowsError(try model.core.call("fileDelete", args))
        var stale = args; stale["confirmed"] = true; stale["session"] = UUID().uuidString
        XCTAssertThrowsError(try model.core.call("fileDelete", stale))
        for root in ["/", "C:\\", "//server/share", "/Remote/../escape"] {
            var request = args; request["confirmed"] = true; request["path"] = root
            XCTAssertThrowsError(try model.core.call("fileDelete", request))
        }
        XCTAssertEqual(try NativeRemoteDeleteTarget.descendant("Nested/file.txt", root: "/Folder"), "/Folder/Nested/file.txt")
        XCTAssertThrowsError(try NativeRemoteDeleteTarget.descendant("../escape", root: "/Folder"))
        XCTAssertThrowsError(try NativeRemoteDeleteTarget.descendant("/absolute", root: "/Folder"))
    }

    func testBatchLocalDownloadDeletionKeepsUnselectedFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = root.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let remove = root.appendingPathComponent("remove.txt")
        let keep = root.appendingPathComponent("keep.txt")
        for url in [remove, keep, folder.appendingPathComponent("nested.txt")] { try Data("data".utf8).write(to: url) }
        let files = NativeFileModel()
        files.downloads = [remove, keep, folder].map { NativeDownloadedFile(url: $0, size: 4, date: Date(), source: nil) }
        files.downloadedURL = remove
        await files.deleteDownloads([remove, folder])
        XCTAssertFalse(FileManager.default.fileExists(atPath: remove.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keep.path))
        XCTAssertEqual(files.downloads.map(\.url), [keep])
        XCTAssertNil(files.downloadedURL)
        XCTAssertFalse(files.deletingLocalDownloads)
        XCTAssertTrue(files.localDownloadDeletionError.isEmpty)
    }

    func testRemoteDirectoryErrorsFinishLoadingAndAllowRetry() async throws {
        let files = NativeFileModel()
        defer { files.reset() }
        files.loading = true; files.status = "正在读取目录…"
        files.load("/Another")
        XCTAssertTrue(files.loading)
        XCTAssertEqual(files.status, "正在读取目录…")
        files.handle(["name": "job_error", "id": "9", "err": "Other job"])
        XCTAssertTrue(files.loading)
        files.handle(["name": "job_error", "id": "0", "err": "Permission denied"])
        XCTAssertFalse(files.loading)
        XCTAssertEqual(files.status, "Permission denied")
        files.handle(["name": "file_dir", "is_local": "false", "value": "invalid"])
        for _ in 0..<100 { if !files.loading { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(files.loading)
        XCTAssertEqual(files.status, "目录数据格式无效，请刷新重试")
    }
    func testPeerInfoRefreshDoesNotRestartConnectedFileBrowser() {
        let model = NativeShellModel(window: UUID().uuidString)
        defer { model.closeSession() }
        model.remoteKind = .files; model.connected = true
        model.fileBrowser.path = "/Documents"; model.fileBrowser.status = "2 个项目"
        model.handle(["name": "sync_peer_info"])
        XCTAssertEqual(model.fileBrowser.path, "/Documents")
        XCTAssertEqual(model.fileBrowser.status, "2 个项目")
        XCTAssertFalse(model.fileBrowser.loading)
    }
    func testSavedPeerRemovalAndPasswordClearPersistThroughRefresh() async throws {
        let model = NativeShellModel(window: UUID().uuidString)
        let id = "native-peer-" + UUID().uuidString
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("peers")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(id + ".toml")
        defer { try? FileManager.default.removeItem(at: file); model.closeSession() }
        try "password = [1, 2, 3]\n[info]\nplatform = \"Mac OS\"\nhostname = \"Fixture\"\n".write(to: file, atomically: true, encoding: .utf8)
        await model.refresh()
        let peer = try XCTUnwrap(model.peers.first { $0.id == id })
        XCTAssertTrue(peer.hasPassword)
        model.peerAction(peer, "forgetPassword")
        await model.refresh()
        XCTAssertFalse(try XCTUnwrap(model.peers.first { $0.id == id }).hasPassword)
        model.peerAction(peer, "remove")
        await model.refresh()
        XCTAssertFalse(model.peers.contains { $0.id == id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testQRScanRegionCentersWithinEachWindowSize() {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 744, height: 1080), CGSize(width: 1080, height: 744)] {
            let region = NativeQRConnectionView.scanRect(in: size)
            XCTAssertEqual(region.midX, size.width / 2)
            XCTAssertEqual(region.midY, size.height / 2)
            XCTAssertEqual(region.width, region.height)
            XCTAssertTrue(CGRect(origin: .zero, size: size).contains(region))
        }
    }
    func testQRConnectionAcceptsRemoteIDsWithoutOpeningArbitraryLinks() {
        XCTAssertEqual(NativeQRConnectionView.remoteID(from: "160111967"), "160111967")
        XCTAssertEqual(NativeQRConnectionView.remoteID(from: "rustdesk://160111967"), "160111967")
        XCTAssertEqual(NativeQRConnectionView.remoteID(from: "rustdesk://connection?id=160111967"), "160111967")
        XCTAssertNil(NativeQRConnectionView.remoteID(from: "https://example.com"))
        XCTAssertNil(NativeQRConnectionView.remoteID(from: "config=server-secret"))
    }
    func testAllNativeInputModesPersistThroughCoreRefresh() throws {
        let original = try NativeRustCore.call("refresh")["inputMode"] as? String ?? "mouse"
        defer { _ = try? NativeRustCore.call("inputMode", ["value": original]) }
        for mode in ["mouse", "touch", "touch-new", "trackpad"] {
            _ = try NativeRustCore.call("inputMode", ["value": mode])
            XCTAssertEqual(try NativeRustCore.call("refresh")["inputMode"] as? String, mode)
        }
    }
    func testAllInputModesReceiveMultiTouchInLetterboxMargins() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        defer { window.isHidden = true }
        for mode in ["mouse", "trackpad", "touch-new", "touch"] {
            let model = NativeShellModel()
            model.remoteID = "native-hit-test"; model.connected = true; model.inputMode = mode
            window.rootViewController = NativeHostingController(model: model)
            window.isHidden = false
            window.layoutIfNeeded()
            await Task.yield()
            window.layoutIfNeeded()
            let canvas = try XCTUnwrap(model.canvas)
            XCTAssertTrue(canvas.isMultipleTouchEnabled)
            for size in [CGSize(width: 320, height: 640), CGSize(width: 640, height: 320)] {
                window.frame.size = size
                window.rootViewController?.view.frame = window.bounds
                window.layoutIfNeeded()
                await Task.yield()
                model.inputMode = mode
                window.layoutIfNeeded()
                let rect = canvas.convert(canvas.bounds, to: window)
                XCTAssertEqual(rect.width, window.bounds.width, accuracy: 1)
                XCTAssertEqual(rect.height, window.bounds.height, accuracy: 1)
                let imageSize = CGSize(width: size.height, height: size.width)
                let image = UIGraphicsImageRenderer(size: imageSize).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: imageSize)) }
                canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
                let video = try XCTUnwrap(canvas.layer.sublayers?.first)
                let points = [CGPoint(x: rect.width * 0.15, y: rect.height * 0.15), CGPoint(x: rect.width * 0.75, y: rect.height * 0.85),
                              CGPoint(x: rect.width * 0.25, y: rect.height * 0.1), CGPoint(x: rect.width * 0.85, y: rect.height * 0.65)]
                for point in points {
                    XCTAssertFalse(video.frame.contains(point))
                    let hit = try XCTUnwrap(window.hitTest(canvas.convert(point, to: window), with: nil))
                    XCTAssertTrue(hit === canvas || hit.isDescendant(of: canvas), "\(mode): margin touch intercepted by \(type(of: hit))")
                }
            }
            canvas.stop(); model.closeSession()
        }
    }
    func testPinchInLetterboxZoomsVisibleImageFromItsCenter() throws {
        let model = NativeShellModel()
        let canvas = NativeCanvasView(model: model)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        defer { canvas.stop() }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360)).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        let initial = video.frame
        let blackMargin = CGPoint(x: 100, y: 80)
        XCTAssertFalse(initial.contains(blackMargin))
        canvas.zoom(by: 2, at: blackMargin)
        XCTAssertEqual(video.frame.width, initial.width * 2, accuracy: 1)
        XCTAssertEqual(video.frame.midX, initial.midX, accuracy: 1)
        XCTAssertEqual(video.frame.midY, initial.midY, accuracy: 1)
        canvas.zoom(by: 0.5, at: blackMargin)
        XCTAssertEqual(video.frame, initial)
        let anchor = CGPoint(x: 100, y: initial.midY - 20)
        let remoteX = (anchor.x - initial.minX) / initial.width
        let remoteY = (anchor.y - initial.minY) / initial.height
        canvas.zoom(by: 1.2, at: anchor)
        XCTAssertEqual(video.frame.minX + remoteX * video.frame.width, anchor.x, accuracy: 1)
        XCTAssertEqual(video.frame.minY + remoteY * video.frame.height, anchor.y, accuracy: 1)
    }
    func testHiDPICurrentResolutionStaysSelectable() {
        let model = NativeShellModel()
        model.handle(["name": "peer_info", "current_display": "0", "displays": "[{\"width\":3200,\"height\":2400,\"scaled_width\":1600}]", "resolutions": "[{\"width\":1920,\"height\":1080}]"])
        XCTAssertEqual(model.currentResolution, NativeResolution(width: 1600, height: 1200))
        XCTAssertTrue(model.resolutionChoices.contains(NativeResolution(width: 1600, height: 1200)))
        model.handle(["name": "switch_display", "display": "0", "width": "3840", "height": "2160"])
        XCTAssertEqual(model.currentResolution, NativeResolution(width: 1920, height: 1080))
    }
    func testQueuedResolutionCannotTargetAReplacementSession() async throws {
        let model = NativeShellModel()
        await model.connect(to: "127.0.0.1:9")
        defer { model.closeSession() }
        do {
            try await NativeRustCore.changeResolution(session: UUID().uuidString, display: 0, resolution: NativeResolution(width: 1280, height: 720))
            XCTFail("A stale session must not change a current desktop")
        } catch { XCTAssertTrue(error.localizedDescription.contains("远程连接已变更")) }
    }
    func testResolutionValidationPreservesExactModeDimensions() {
        for size in [CGSize(width: 1179, height: 2556), CGSize(width: 2556, height: 1179), CGSize(width: 2079, height: 2211)] {
            XCTAssertEqual(NativeResolution.windowPixels(size), NativeResolution(width: Int(size.width), height: Int(size.height)))
        }
        XCTAssertNil(NativeResolution.windowPixels(.zero))
        XCTAssertNil(NativeResolution.windowPixels(CGSize(width: 9000, height: 2100)))
    }
    func testRemoteResolutionsAndDisplayChangesStayInSync() {
        let model = NativeShellModel()
        model.handle(["name": "peer_info", "current_display": "0", "displays": "[{\"x\":0,\"y\":0,\"width\":1920,\"height\":1080,\"original_width\":1920,\"original_height\":1080}]", "resolutions": "[{\"width\":1920,\"height\":1080},{\"width\":1080,\"height\":1920},{\"width\":1800,\"height\":1920},{\"width\":0,\"height\":0}]"])
        XCTAssertEqual(model.resolutions.count, 3)
        XCTAssertEqual(model.displays.first?.originalResolution, NativeResolution(width: 1920, height: 1080))
        model.handle(["name": "switch_display", "display": "0", "width": "1800", "height": "1920", "original_width": "0", "original_height": "0", "resolutions": "{\"resolutions\":[{\"width\":1800,\"height\":1920}]}"])
        XCTAssertEqual(model.displays.first?.size, CGSize(width: 1800, height: 1920))
        XCTAssertEqual(model.displays.first?.customResolution, true)
        XCTAssertEqual(model.resolutions, [NativeResolution(width: 1800, height: 1920)])
    }
    func testShortcutPanelHeightMatchesExpandedPortraitAndLandscape() throws {
        let model = NativeShellModel()
        let canvas = NativeCanvasView(model: model)
        defer { canvas.stop() }
        let input = try XCTUnwrap(canvas.subviews.compactMap { $0 as? UITextView }.first)
        for (size, expected) in [(CGSize(width: 900, height: 1280), 480.0), (CGSize(width: 1280, height: 900), 351.0), (CGSize(width: 420, height: 912), 410.4), (CGSize(width: 450, height: 720), 324.0), (CGSize(width: 912, height: 420), 240.0), (CGSize(width: 640, height: 910), 341.25)] {
            canvas.frame.size = size
            canvas.layoutIfNeeded()
            canvas.showShortcutKeyboard()
            XCTAssertEqual(try XCTUnwrap(input.inputView).frame.height, expected, accuracy: 1)
            canvas.hideSystemKeyboard()
        }
    }
    func testManualFitAndKeyboardAlignmentSurviveWindowResize() throws {
        let model = NativeShellModel()
        let canvas = NativeCanvasView(model: model)
        defer { canvas.stop() }
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360)).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 640, height: 360)) }
        canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
        canvas.layoutIfNeeded()
        canvas.zoom(by: 1.8)
        canvas.frame.size = CGSize(width: 700, height: 740)
        canvas.layoutIfNeeded()
        canvas.fit()
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        XCTAssertEqual(video.frame.width, 700, accuracy: 1)
        XCTAssertTrue(canvas.bounds.contains(video.frame))
        canvas.setKeyboardLift(400)
        XCTAssertLessThanOrEqual(video.frame.width, 700)
        XCTAssertEqual(video.frame.maxY, 340, accuracy: 1)
        canvas.setKeyboardLift(0)
        canvas.frame.size = CGSize(width: 740, height: 500)
        canvas.layoutIfNeeded()
        XCTAssertEqual(video.frame.width, 740, accuracy: 1)
        XCTAssertTrue(canvas.bounds.contains(video.frame))
    }
    func testNativeResolutionChangesRespectReadOnlyMode() async throws {
        let model = NativeShellModel()
        await model.connect(to: "127.0.0.1:9")
        defer { _ = try? NativeRustCore.call("sessionOption", ["key": "view-only", "value": false]); model.closeSession() }
        _ = try NativeRustCore.call("sessionOption", ["key": "view-only", "value": true])
        XCTAssertThrowsError(try NativeRustCore.call("resolution", ["display": 0, "width": 1280, "height": 720])) {
            XCTAssertTrue($0.localizedDescription.contains("远端未允许修改分辨率"))
        }
    }
    func testZoomOutLimitKeepsDesktopAtLeastWindowWidth() throws {
        let key = "native.limit-zoom-to-width", previous = UserDefaults.standard.object(forKey: "native.limit-zoom-to-width")
        defer { UserDefaults.standard.set(previous, forKey: key) }
        let model = NativeShellModel(), canvas: NativeCanvasView
        canvas = NativeCanvasView(model: model)
        defer { canvas.stop() }
        canvas.frame = CGRect(x: 0, y: 0, width: 420, height: 912)
        for size in [CGSize(width: 1280, height: 720), CGSize(width: 360, height: 1920)] {
            model.setLimitZoomToWidth(false)
            let image = UIGraphicsImageRenderer(size: size).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size)) }
            canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
            model.setLimitZoomToWidth(true)
            canvas.zoom(by: 0.01)
            let video = try XCTUnwrap(canvas.layer.sublayers?.first)
            XCTAssertEqual(video.frame.width, canvas.bounds.width, accuracy: 1)
            canvas.fit()
            XCTAssertGreaterThanOrEqual(video.frame.width, canvas.bounds.width - 1)
            model.setLimitZoomToWidth(false)
            canvas.zoom(by: 0.25)
            XCTAssertLessThan(video.frame.width, canvas.bounds.width)
        }
    }
    func testTwoFingerScrollingRemainsLockedUntilRelease() {
        var gesture = NativeTwoFingerGesture()
        gesture.begin(first: CGPoint(x: 80, y: 80), second: CGPoint(x: 180, y: 80))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 80, y: 82), second: CGPoint(x: 181, y: 82)), .scroll(.zero))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 110, y: 140), second: CGPoint(x: 211, y: 142)), .scroll(CGPoint(x: 0, y: 61)))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 90, y: 150), second: CGPoint(x: 230, y: 150)), .scroll(CGPoint(x: 0, y: 9)))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 70, y: 130), second: CGPoint(x: 250, y: 130)), .scroll(CGPoint(x: 0, y: -20)))
        gesture.end()
        gesture.begin(first: CGPoint(x: 80, y: 80), second: CGPoint(x: 180, y: 80))
        if case .transform = gesture.move(first: CGPoint(x: 60, y: 80), second: CGPoint(x: 200, y: 80)) {} else { XCTFail("A fresh gesture must allow pinch after scrolling") }
    }
    func testPinchKeepsCanvasDraggingUntilRelease() {
        var gesture = NativeTwoFingerGesture()
        gesture.begin(first: CGPoint(x: 80, y: 80), second: CGPoint(x: 180, y: 80))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 60, y: 80), second: CGPoint(x: 200, y: 80)), .transform(1.4, CGPoint(x: 130, y: 80), CGPoint(x: 130, y: 80)))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 90, y: 110), second: CGPoint(x: 230, y: 110)), .transform(1, CGPoint(x: 130, y: 80), CGPoint(x: 160, y: 110)))
        gesture.end()
        gesture.begin(first: CGPoint(x: 90, y: 110), second: CGPoint(x: 230, y: 110))
        XCTAssertEqual(gesture.move(first: CGPoint(x: 90, y: 130), second: CGPoint(x: 230, y: 130)), .scroll(CGPoint(x: 0, y: 20)))
    }
    func testTwoFingerCanvasTransformCombinesPinchAndTranslation() throws {
        let model = NativeShellModel()
        let canvas = NativeCanvasView(model: model)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        defer { canvas.stop() }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360)).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        let original = video.frame
        canvas.transformCanvas(by: 1.5, from: CGPoint(x: 100, y: 60), to: CGPoint(x: 140, y: 90))
        XCTAssertEqual(video.frame.width, original.width * 1.5, accuracy: 1)
        XCTAssertEqual(video.frame.midX, original.midX + 40, accuracy: 1)
        XCTAssertEqual(video.frame.midY, original.midY + 30, accuracy: 1)
        let enlarged = video.frame
        canvas.transformCanvas(by: 1, from: CGPoint(x: 140, y: 90), to: CGPoint(x: 120, y: 80))
        XCTAssertEqual(video.frame.width, enlarged.width, accuracy: 1)
        XCTAssertEqual(video.frame.minX, enlarged.minX - 20, accuracy: 1)
        XCTAssertEqual(video.frame.minY, enlarged.minY - 10, accuracy: 1)
        model.canvasLocked = true
        let locked = video.frame
        canvas.transformCanvas(by: 2, from: .zero, to: CGPoint(x: 50, y: 50))
        XCTAssertEqual(video.frame, locked)
    }
    func testKeyboardTopAlignmentAtDifferentZoomsAndKeyboardHeights() throws {
        let model = NativeShellModel()
        let canvas = NativeCanvasView(model: model)
        canvas.frame = CGRect(x: 0, y: 0, width: 420, height: 912)
        defer { canvas.stop() }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1280, height: 720)).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1280, height: 720))
        }
        canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        for factor in [0.75, 2.0] {
            canvas.zoom(by: factor)
            let before = video.frame
            canvas.setKeyboardLift(300)
            XCTAssertEqual(video.frame.maxY, 612, accuracy: 1)
            XCTAssertEqual(video.frame.size, before.size)
            canvas.setKeyboardLift(360)
            XCTAssertEqual(video.frame.maxY, 552, accuracy: 1)
            XCTAssertEqual(video.frame.size, before.size)
            canvas.setKeyboardLift(0)
            XCTAssertEqual(video.frame, before)
        }
    }
    func testDirectTouchOnlyAcceptsDesktopImageWhileMarginZoomRemainsAvailable() throws {
        let model = NativeShellModel()
        let canvas = NativeCanvasView(model: model)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        defer { canvas.stop() }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360)).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 640, height: 360))
        }
        canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        for mode in ["touch", "touch-new"] {
            model.inputMode = mode
            canvas.fit()
            let original = video.frame
            XCTAssertTrue(canvas.acceptsDirectTouch(at: CGPoint(x: original.midX, y: original.midY)))
            XCTAssertFalse(canvas.acceptsDirectTouch(at: CGPoint(x: 100, y: 80)))
            XCTAssertFalse(canvas.acceptsDirectTouch(at: CGPoint(x: original.midX, y: original.maxY + 1)))
            canvas.transformCanvas(by: 1.5, from: CGPoint(x: 100, y: 80), to: CGPoint(x: 120, y: 100))
            XCTAssertEqual(video.frame.width, original.width * 1.5, accuracy: 1)
            XCTAssertFalse(canvas.acceptsDirectTouch(at: CGPoint(x: 100, y: 80)))
            XCTAssertTrue(canvas.acceptsDirectTouch(at: CGPoint(x: video.frame.midX, y: video.frame.midY)))
        }
    }
    func testCustomShortcutsPersistEditsOrderAndModifierArguments() throws {
        let name = "native-shortcut-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let library = NativeShortcutLibrary(defaults: defaults)
        let custom = NativeShortcut(title: "测试组合", key: "VK_K", modifiers: ["ctrl", "shift"])
        library.save(custom)
        library.move(from: IndexSet(integer: library.items.count - 1), to: 0)
        let reloaded = NativeShortcutLibrary(defaults: defaults)
        XCTAssertEqual(reloaded.items.first, custom)
        XCTAssertEqual(custom.arguments["value"] as? String, "VK_K")
        XCTAssertEqual(custom.arguments["ctrl"] as? Bool, true)
        XCTAssertEqual(custom.arguments["shift"] as? Bool, true)
        XCTAssertNil(custom.arguments["command"])
        var edited = custom; edited.title = "修改名称"; edited.key = "VK_F5"
        reloaded.save(edited)
        XCTAssertEqual(NativeShortcutLibrary(defaults: defaults).items.first, edited)
        reloaded.delete(at: IndexSet(integer: 0))
        XCTAssertFalse(NativeShortcutLibrary(defaults: defaults).items.contains { $0.id == custom.id })
    }
    func testShortcutPanelOpensWithoutPresentingTheSystemKeyboard() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let model = NativeShellModel()
        model.remoteID = "native-no-keyboard-flash"
        window.rootViewController = NativeHostingController(model: model)
        window.makeKeyAndVisible()
        defer { model.canvas?.stop(); window.isHidden = true; previous?.makeKeyAndVisible(); model.closeSession() }
        await Task.yield(); window.layoutIfNeeded()
        let canvas = try XCTUnwrap(model.canvas)
        let input = try XCTUnwrap(canvas.subviews.compactMap { $0 as? UITextView }.first)
        var presentedSystemKeyboard = false
        let observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { notification in
            MainActor.assumeIsolated {
                if model.remoteKeyboardVisible, input.isFirstResponder, input.inputView == nil,
                   let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                   window.bounds.intersects(window.convert(frame, from: nil)) { presentedSystemKeyboard = true }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        for _ in 0..<2 {
            canvas.showShortcutKeyboard()
            XCTAssertNotNil(input.inputView, "The custom panel must be installed before keyboard presentation")
            let shown = expectation(for: NSPredicate { _, _ in input.inputView?.window != nil }, evaluatedWith: nil)
            await fulfillment(of: [shown], timeout: 5)
            XCTAssertFalse(presentedSystemKeyboard)
            let panel = input.inputView
            let originalFrame = canvas.frame
            canvas.frame.size.height -= 20
            canvas.layoutIfNeeded()
            XCTAssertTrue(input.inputView === panel, "Content layout with a stable window must not recreate the keyboard or release dragging")
            canvas.frame = originalFrame; canvas.layoutIfNeeded()
            canvas.hideSystemKeyboard()
            XCTAssertFalse(input.isFirstResponder)
        }
    }
    func testSystemKeyboardAlignsVideoBottomAndRestoresCanvas() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let model = NativeShellModel()
        model.remoteID = "native-keyboard-layout"
        window.rootViewController = NativeHostingController(model: model)
        var keyboardEndFrame: CGRect?
        let keyboardObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { notification in
            keyboardEndFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        }
        defer { NotificationCenter.default.removeObserver(keyboardObserver) }
        window.makeKeyAndVisible()
        defer { model.canvas?.stop(); window.isHidden = true; previousWindow?.makeKeyAndVisible(); model.closeSession() }
        await Task.yield()
        window.layoutIfNeeded()
        let canvas = try XCTUnwrap(model.canvas)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1280, height: 720)).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1280, height: 720))
        }
        canvas.displayFrame(try XCTUnwrap(image.cgImage), display: 0)
        canvas.remoteCursor(CGPoint(x: 640, y: 360))
        canvas.zoom(by: 1.25)
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        let pointer = try XCTUnwrap(canvas.layer.sublayers?[1])
        let original = video.frame, originalPointer = pointer.frame
        UIView.animate(withDuration: 0.25) { canvas.setKeyboardLift(12) }
        XCTAssertNil(pointer.animation(forKey: "keyboardPosition"), "Pointer motion must not be held by keyboard animation")
        canvas.setKeyboardLift(0)
        let raised = expectation(for: NSPredicate { _, _ in video.frame.minY < original.minY - 10 }, evaluatedWith: nil)
        canvas.showSystemKeyboard()
        await fulfillment(of: [raised], timeout: 5)
        window.layoutIfNeeded()
        let keyboardFrame = window.convert(try XCTUnwrap(keyboardEndFrame), from: nil)
        let lift = window.bounds.intersection(keyboardFrame).height
        XCTAssertGreaterThan(lift, 0)
        XCTAssertEqual(video.frame.maxY, keyboardFrame.minY, accuracy: 1)
        canvas.setKeyboardLift(lift + 0.1)
        XCTAssertEqual(video.frame.maxY, keyboardFrame.minY, accuracy: 0.05, "Subpixel keyboard layout noise must not keep shifting the canvas")
        XCTAssertEqual(originalPointer.minY - pointer.frame.minY, original.minY - video.frame.minY, accuracy: 1)
        XCTAssertEqual(video.frame.size, original.size)
        XCTAssertEqual(pointer.frame.size, originalPointer.size)
        let raisedFrame = video.frame
        canvas.zoom(by: 1)
        XCTAssertEqual(video.frame, raisedFrame, "Zooming with the keyboard open must not add another vertical offset")
        let restored = expectation(for: NSPredicate { _, _ in abs(video.frame.minY - original.minY) < 1 }, evaluatedWith: nil)
        canvas.hideSystemKeyboard()
        await fulfillment(of: [restored], timeout: 5)
        XCTAssertEqual(video.frame.minY, original.minY, accuracy: 1)
        XCTAssertEqual(pointer.frame.minY, originalPointer.minY, accuracy: 1)
        let shortcutVisible = expectation(for: NSPredicate { _, _ in
            guard let frame = keyboardEndFrame else { return false }
            let local = window.convert(frame, from: nil)
            let input = canvas.subviews.compactMap { $0 as? UITextView }.first
            return input?.inputView != nil && model.remoteKeyboardVisible && local.minY < window.bounds.maxY && abs(video.frame.maxY - local.minY) < 1
        }, evaluatedWith: nil)
        canvas.showShortcutKeyboard()
        await fulfillment(of: [shortcutVisible], timeout: 5)
        let shortcutFrame = window.convert(try XCTUnwrap(keyboardEndFrame), from: nil)
        XCTAssertEqual(shortcutFrame.minY / window.bounds.height, 0.55, accuracy: 0.02, "Shortcut panel should match the keyboard proportion in the reference screenshot")
        XCTAssertEqual(video.frame.maxY, shortcutFrame.minY, accuracy: 1)
        XCTAssertEqual(video.frame.size, original.size)
        let shortcutClosed = expectation(for: NSPredicate { _, _ in abs(video.frame.minY - original.minY) < 1 }, evaluatedWith: nil)
        canvas.hideSystemKeyboard()
        await fulfillment(of: [shortcutClosed], timeout: 5)
    }
    func testTerminalKeyboardContentFillsChangingWindowWidths() throws {
        let terminal = NativeTerminalCanvas(model: NativeTerminalModel())
        XCTAssertNil(terminal.inputAccessoryView, "Toolbar belongs to the app layout, not the system keyboard container")
        let panel = NativeShortcutInputView(model: NativeShellModel(), height: 300, width: 390)
        for width in [CGFloat(390), 690, 920, 600] {
            for view in [panel] {
                view.frame.size.width = width
                view.setNeedsLayout(); view.layoutIfNeeded()
                let content = try XCTUnwrap(view.constraints.first(where: { $0.firstAttribute == .leading && $0.firstItem as? UIView !== view })?.firstItem as? UIView)
                XCTAssertEqual(content.frame.minX, 0, accuracy: 0.5)
                XCTAssertEqual(content.frame.width, width, accuracy: 0.5)
            }
        }
    }
    func testTerminalShortcutKeysUsePTYCharactersAndXtermNavigation() {
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_C", modifiers: ["ctrl"]), "\u{03}")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_D", modifiers: ["ctrl"]), "\u{04}")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_RETURN", modifiers: []), "\r")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_A", modifiers: []), "a")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_A", modifiers: ["shift"]), "A")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_UP", modifiers: []), "\u{1b}[A")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_UP", modifiers: [], applicationCursor: true), "\u{1b}OA")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_LEFT", modifiers: ["ctrl"]), "\u{1b}[1;5D")
        XCTAssertEqual(NativeTerminalKeys.sequence("VK_F5", modifiers: []), "\u{1b}[15~")
        XCTAssertEqual(NativeTerminalKeys.text("[", modifiers: ["ctrl"]), "\u{1b}")
        XCTAssertEqual(NativeTerminalKeys.text("x", modifiers: ["alt"]), "\u{1b}x")
        XCTAssertTrue(NativeTerminalKeys.isLocalCommand("VK_V", modifiers: ["command"]))
        XCTAssertNil(NativeTerminalKeys.sequence("VK_S", modifiers: ["command"]))
        XCTAssertNil(NativeTerminalKeys.text("ß", modifiers: ["ctrl"]))
    }
    func testTerminalTabsKeepSeparateOutputAndSelection() throws {
        let tabs = NativeTerminalTabs()
        let first = tabs.active
        let firstView = NativeTerminalCanvas(model: first)
        firstView.frame = CGRect(x: 0, y: 0, width: 500, height: 300); firstView.layoutIfNeeded()
        tabs.add(connected: false)
        let second = tabs.active
        let secondView = NativeTerminalCanvas(model: second)
        secondView.frame = firstView.frame; secondView.layoutIfNeeded()
        tabs.handle(["terminal_id": first.id, "type": "data", "data": Data("first shell".utf8).base64EncodedString()])
        tabs.handle(["terminal_id": second.id, "type": "data", "data": Data("second shell".utf8).base64EncodedString()])
        XCTAssertTrue(try XCTUnwrap(firstView.getTerminal().getLine(row: 0)).translateToString(trimRight: true).contains("first shell"))
        XCTAssertTrue(try XCTUnwrap(secondView.getTerminal().getLine(row: 0)).translateToString(trimRight: true).contains("second shell"))
        tabs.select(first)
        XCTAssertEqual(tabs.active.id, first.id)
        first.title = "日志"
        XCTAssertEqual(tabs.active.title, "日志")
        tabs.closeActive()
        XCTAssertEqual(tabs.tabs.count, 1)
        XCTAssertEqual(tabs.active.id, second.id)
        tabs.reset()
        XCTAssertEqual(tabs.active.id, 1)
        XCTAssertEqual(tabs.tabs.count, 1)
    }
    func testTerminalWaitsForActualLayoutBeforeOpeningShell() async throws {
        let shell = NativeShellModel()
        await shell.connect(to: "127.0.0.1:9", kind: .terminal)
        defer { shell.closeSession() }
        let terminal = shell.terminalSession.active
        terminal.open()
        XCTAssertEqual(terminal.status, "正在准备终端尺寸…")
        let view = NativeTerminalCanvas(model: terminal)
        view.frame = CGRect(x: 0, y: 0, width: 375, height: 400)
        view.layoutIfNeeded()
        await Task.yield()
        let size = view.getTerminal().getDims()
        XCTAssertNotEqual(size.cols, 80)
        terminal.handle(["terminal_id": terminal.id, "type": "opened", "success": true])
        XCTAssertEqual(terminal.status, "已连接 · \(size.cols) × \(size.rows)")
    }
    func testSessionSettingsUseActiveConnectionOptions() async throws {
        let model = NativeShellModel()
        await model.connect(to: "127.0.0.1:9")
        defer { model.closeSession() }
        let initial = try XCTUnwrap(try NativeRustCore.call("sessionSettings")["sessionSettings"] as? [String: Any])
        let quality = initial["quality"] as? String ?? "balanced"
        defer { _ = try? NativeRustCore.call("sessionOption", ["key": "image-quality", "value": quality]) }
        let updated = try NativeRustCore.call("sessionOption", ["key": "image-quality", "value": "low"])
        XCTAssertEqual((updated["sessionSettings"] as? [String: Any])?["quality"] as? String, "low")
        XCTAssertThrowsError(try NativeRustCore.call("sessionOption", ["key": "unknown-option", "value": true]))
        XCTAssertThrowsError(try NativeRustCore.call("sessionOption", ["key": "codec-preference", "value": "invalid-codec"]))
    }
    func testSkippedConnectionErrorsStayNonmodalAndAuthenticationStillAppears() async throws {
        let model = NativeShellModel()
        await model.connect(to: "127.0.0.1:9")
        let message = NativeConnectionMessage(type: "error", title: "连接错误", text: "连接超时", hasRetry: true, sourceTitle: "Connection Error")
        model.setPromptSkipped(message, true)
        defer { model.setPromptSkipped(message, false); model.closeSession() }
        let event: [String: Any] = ["name": "msgbox", "type": "error", "title": "连接错误", "sourceTitle": "Connection Error", "text": "连接超时", "hasRetry": "true"]
        model.handle(event); model.handle(event)
        XCTAssertNil(model.prompt)
        XCTAssertNotEqual(model.sheet, .connectionPrompt)
        XCTAssertEqual(model.connectionFailure?.text, "连接超时")
        model.handle(["name": "msgbox", "type": "error", "sourceTitle": "Connection Error", "text": "远端离线", "hasRetry": ""])
        XCTAssertNil(model.prompt)
        XCTAssertEqual(model.connectionFailure?.text, "远端离线")
        model.handle(["name": "msgbox", "type": "input-password", "sourceTitle": "Connection Error", "title": "连接认证"])
        XCTAssertTrue(try XCTUnwrap(model.prompt).password)
        XCTAssertEqual(model.sheet, .connectionPrompt)
        model.setPromptSkipped(message, false)
        model.handle(event)
        XCTAssertNil(model.sheet)
        XCTAssertEqual(model.prompt?.text, "连接超时")
    }
    func testAuthenticationIdentityUsesCachedAndLivePeerInformation() async throws {
        let model = NativeShellModel()
        model.peers = [NativePeer(id: "127.0.0.1:9", name: "办公电脑", platform: "Mac OS", favorite: false, username: "alice", hostname: "mac.lan")]
        await model.connect(to: "127.0.0.1:9")
        defer { model.closeSession() }
        XCTAssertEqual(model.remoteIdentity, "alice@mac.lan")
        model.handle(["name": "peer_info", "username": "bob", "hostname": "mac-mini"])
        XCTAssertEqual(model.remoteIdentity, "bob@mac-mini")
    }
    func testCursorRejectsTruncatedPixelsAndPreservesHotspot() throws {
        XCTAssertNil(NativeRustCore.cursor(["width": 2, "height": 2, "colors": Data([0, 0, 0]).base64EncodedString()]))
        let cursor = try cursor()
        XCTAssertEqual(cursor.image.width, 2)
        XCTAssertEqual(cursor.hotspot, CGPoint(x: 1, y: 1))
        let pixels = try XCTUnwrap(cursor.image.dataProvider?.data) as Data
        XCTAssertEqual(Array(pixels.prefix(4)), [255, 0, 0, 255])
    }
    func testNativeRenderingKeepsPointerSizeIndependentOfCanvasZoom() throws {
        let model = NativeShellModel()
        model.cursor = try cursor()
        let canvas = NativeCanvasView(model: model)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        canvas.remoteCursor(CGPoint(x: 1, y: 0))
        canvas.displayFrame(try cursor().image, display: 0)
        let video = try XCTUnwrap(canvas.layer.sublayers?.first)
        let pointer = try XCTUnwrap(canvas.layer.sublayers?.dropFirst().first)
        XCTAssertEqual(video.frame.size, CGSize(width: 240, height: 240))
        XCTAssertEqual(pointer.frame.width, 28, accuracy: 0.01)
        let hotspotBefore = CGPoint(x: pointer.frame.minX + 14, y: pointer.frame.minY + 14)
        XCTAssertEqual(hotspotBefore.y, 0, accuracy: 0.01)
        canvas.zoom(by: 2)
        XCTAssertEqual(video.frame.width, 480, accuracy: 0.01)
        XCTAssertEqual(pointer.frame.width, 28, accuracy: 0.01)
        XCTAssertEqual(pointer.frame.minX + 14, hotspotBefore.x, accuracy: 0.01)
        model.cursorSize = 44; canvas.updateCursor()
        XCTAssertEqual(pointer.frame.width, 44, accuracy: 0.01)
        canvas.stop()
        let recreated = NativeCanvasView(model: model)
        recreated.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        XCTAssertNotNil(recreated.layer.sublayers?.first?.contents)
        recreated.stop(); model.closeSession()
        XCTAssertNil(model.lastFrame)
        XCTAssertNil(model.cursorPosition)
    }
    func testAppHierarchyContainsNoFlutterControllers() throws {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        XCTAssertFalse(windows.isEmpty)
        XCTAssertFalse(Bundle.allFrameworks.contains { $0.bundleURL.lastPathComponent == "Flutter.framework" })
        func verify(_ controller: UIViewController) {
            XCTAssertFalse(String(describing: type(of: controller)).contains("Flutter"))
            controller.children.forEach(verify)
            if let presented = controller.presentedViewController { verify(presented) }
        }
        for window in windows { if let root = window.rootViewController { verify(root) } }
    }
    func testNativeTerminalRendersANSIAndUTF8Output() throws {
        let terminal = NativeTerminalModel()
        let view = NativeTerminalCanvas(model: terminal)
        view.frame = CGRect(x: 0, y: 0, width: 500, height: 300)
        view.layoutIfNeeded()
        let output = Data("\u{1b}[31mHello\u{1b}[0m 中文\r\n".utf8)
        terminal.handle(["terminal_id": 1, "type": "data", "data": output.base64EncodedString()])
        let rendered = try XCTUnwrap(view.getTerminal().getLine(row: 0)).translateToString(trimRight: true, skipNullCellsFollowingWide: true)
        XCTAssertTrue(rendered.contains("Hello"))
        XCTAssertTrue(rendered.contains("中文"))
        XCTAssertFalse(rendered.contains("\u{1b}[31m"))
        terminal.handle(["terminal_id": 1, "type": "closed", "exit_code": 0])
        XCTAssertFalse(terminal.isOpen)
        XCTAssertTrue(terminal.status.contains("退出码"))
    }
    func testNativeConnectDisconnectClearsSessionAndPendingFrames() async throws {
        let model = NativeShellModel()
        XCTAssertTrue(model.ready)
        await model.connect(to: "127.0.0.1:9")
        XCTAssertEqual(model.remoteID, "127.0.0.1:9")
        let during = try NativeRustCore.call("poll")
        XCTAssertNotNil(during["session"] as? String)
        model.closeSession()
        XCTAssertNil(model.remoteID)
        XCTAssertFalse(model.connected)
        let after = try NativeRustCore.call("poll")
        XCTAssertTrue(after["session"] is NSNull)
        XCTAssertTrue((after["events"] as? [Any])?.isEmpty ?? false)
        XCTAssertNil(NativeRustCore.frame())
    }
}
