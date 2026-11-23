import XCTest

final class NativeFrontendUITests: XCTestCase {
    @MainActor
    func testDictationToolbarEntryAndKeyboardLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "YES", "-NativeUITestSessionKind", "desktop", "-native.language", "zh-cn"]
        app.launch()
        let mic = app.buttons["native.dictation"]
        XCTAssertTrue(mic.waitForExistence(timeout: 10))
        XCTAssertFalse(mic.isEnabled)
        let dock = app.descendants(matching: .any).matching(identifier: "native.floatingControls").firstMatch
        XCTAssertLessThanOrEqual(dock.frame.width, 149)
        app.buttons["native.keyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(mic.exists)
        XCTAssertLessThanOrEqual(dock.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
        XCTAssertLessThanOrEqual(dock.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
    }

    @MainActor
    func testPasswordActionsAreSeparateInsideAccessMenu() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "YES", "-NativeUITestSessionKind", "desktop", "-native.language", "zh-cn"]
        app.launch()
        let settings = app.buttons["native.sessionSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertFalse(app.buttons["native.sendOSPassword"].exists)
        XCTAssertTrue(app.buttons["声音与访问"].waitForExistence(timeout: 5))
        app.buttons["声音与访问"].tap()
        XCTAssertTrue(app.buttons["发送系统密码"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["自动登录"].exists)
        XCTAssertFalse(app.buttons["操作系统密码与自动登录"].exists)
    }

    @MainActor
    func testHomeScreenQuickActionsOpenCommonDeviceSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-native.language", "zh-cn", "-NativeUITestImmersive", "NO", "-native.launch-restore", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let cancel = springboard.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
        let icon = springboard.icons["SwiftRust"].firstMatch
        for _ in 0..<4 { if icon.isHittable { break }; springboard.swipeLeft() }
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        icon.press(forDuration: 1)
        let configure = springboard.buttons["桌面菜单设备"]
        XCTAssertTrue(configure.waitForExistence(timeout: 5))
        XCTAssertTrue(springboard.buttons["添加窗口"].exists)
        XCTAssertTrue(springboard.buttons["扫码连接"].exists)
        configure.tap()
        XCTAssertTrue(app.navigationBars["桌面菜单设备"].waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
    }
    @MainActor
    func testURLSchemeHelpIsAvailableInSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-native.language", "zh-cn", "-NativeUITestImmersive", "NO", "-native.launch-restore", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        let help = app.buttons["native.urlSchemeHelp"]
        for _ in 0..<5 { if help.isHittable { break }; app.swipeUp() }
        help.tap()
        XCTAssertTrue(app.navigationBars["URL Scheme"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["swiftrust://connect?id=160111967&mode=desktop"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
    }
    @MainActor
    func testHomeRefreshSpinnerEndsAfterPullAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-native.language", "zh-cn", "-NativeUITestImmersive", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<2 {
            app.swipeDown()
            XCTAssertTrue(app.activityIndicators.firstMatch.waitForNonExistence(timeout: 5))
            app.tabBars.buttons["收藏"].tap()
            app.tabBars.buttons["主页"].tap()
            XCTAssertTrue(app.activityIndicators.firstMatch.waitForNonExistence(timeout: 5))
        }
    }
    @MainActor
    func testTerminalShortcutPanelPagesSystemKeyboardAndTabSwitching() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "YES", "-NativeUITestSessionKind", "terminal", "-native.language", "zh-cn"]
        app.launch()
        let entry = app.buttons["native.terminalShortcutKeyboard"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let panel = app.descendants(matching: .any).matching(identifier: "native.remoteKeyboard").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        for page in 0...3 {
            app.buttons["native.keyboardPage.\(page)"].tap()
            XCTAssertTrue(panel.exists)
        }
        app.buttons["系统键盘"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        let hideKeyboard = app.buttons["收起终端键盘"].firstMatch
        XCTAssertTrue(hideKeyboard.waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(app.windows.firstMatch.frame.maxX - hideKeyboard.frame.maxX), 16)
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        app.buttons["新增标签页"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["native.terminalTab.2"].exists)
        entry.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        app.buttons["收起终端键盘"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
    }
    @MainActor
    func testRootPagesKeepDockAndSettingsChildrenHideDock() {
        let app = XCUIApplication()
        app.launchArguments = ["-native.language", "zh-cn", "-NativeUITestImmersive", "NO"]
        app.launch()
        let dock = app.tabBars.firstMatch
        func expectDock(_ visible: Bool) {
            let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == %@", NSNumber(value: visible)), object: dock)
            XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: 5), .completed)
        }
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["native.settingsHome"].exists)
        dock.buttons["设置"].tap()
        expectDock(true)
        XCTAssertFalse(app.buttons["native.settingsHome"].exists)
        let privacy = app.buttons["native.privacyStatement"]
        for _ in 0..<7 { if privacy.isHittable { break }; app.swipeUp() }
        privacy.tap()
        XCTAssertTrue(app.navigationBars["隐私声明"].waitForExistence(timeout: 5))
        expectDock(false)
        let policy = app.links["Tailscale 隐私政策"]
        for _ in 0..<6 { if policy.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(policy.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["native.openSource"].tap()
        expectDock(false)
        app.buttons["native.agpl"].tap()
        XCTAssertTrue(app.scrollViews["native.licenseDocument"].waitForExistence(timeout: 5))
        expectDock(false)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        expectDock(true)
        dock.buttons["主页"].tap()
        XCTAssertTrue(dock.waitForExistence(timeout: 5))
        expectDock(true)
        XCTAssertTrue(app.buttons["native.connect"].exists)
    }
    @MainActor
    func testProxySwitchAndAuthKeyEntryAreNativeAndBrandingUsesSwiftRust() {
        let app = XCUIApplication()
        app.launchArguments = ["-native.language", "zh-cn", "-native.tailscale.enabled", "NO"]
        app.launch()
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["登录账号"].exists)
        XCTAssertFalse(app.buttons["登录 RustDesk 账号"].exists)
        let tailscale = app.buttons["native.tailscaleSettings"]
        for _ in 0..<5 { if tailscale.isHittable { break }; app.swipeUp() }
        tailscale.tap()
        let key = app.secureTextFields["native.tailscaleAuthKey"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["native.tailscaleAuthKeyLogin"].isEnabled)
        key.tap(); key.typeText("invalid-auth-key\n")
        XCTAssertFalse(app.buttons["native.tailscaleAuthKeyLogin"].isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let advanced = app.buttons["高级设置"]
        for _ in 0..<5 { if advanced.isHittable { break }; app.swipeUp() }
        advanced.tap(); app.buttons["网络代理"].tap()
        XCTAssertTrue(app.switches["native.proxyEnabled"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["native.proxyAddress"].exists)
    }
    @MainActor
    func testLanguageSettingsSwitchImmediatelyAndPersistAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO", "-native.launch-restore", "NO", "-native.foreground-reconnect", "NO", "-native.tailscale.enabled", "NO"]
        app.launch()
        let settings = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "设置", "Settings")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
        let language = app.buttons["native.languageSettings"]
        for _ in 0..<4 { if language.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(language.waitForExistence(timeout: 5)); language.tap()
        let english = app.buttons["native.language.en"]
        for _ in 0..<3 { if english.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(english.waitForExistence(timeout: 5)); english.tap()
        XCTAssertTrue(app.navigationBars["Language"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["native.translationProvider"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["native.automaticTranslation"].exists)
        app.terminate()
        app.launchArguments = ["-NativeUITestImmersive", "NO", "-native.launch-restore", "NO", "-native.foreground-reconnect", "NO", "-native.tailscale.enabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 5))
        // Restore the Chinese selection for the rest of this existing UI suite.
        app.buttons["Settings"].firstMatch.tap()
        let restore = app.buttons["native.languageSettings"]
        for _ in 0..<4 { if restore.isHittable { break }; app.swipeUp() }
        restore.tap()
        app.buttons["native.language.zh-cn"].tap()
    }
    @MainActor
    func testRepeatedDisconnectAndForegroundReturnToNativeHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestRemoteID", "127.0.0.1:9"]
        app.launch()
        let connect = app.buttons["native.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 10))
        for _ in 0..<3 {
            connect.tap()
            let cancel = app.buttons["取消连接"]
            XCTAssertTrue(app.buttons["native.sessionSettings"].waitForExistence(timeout: 5))
            if cancel.isHittable {
                cancel.tap()
                XCTAssertTrue(app.alerts["断开连接？"].waitForExistence(timeout: 3))
                app.alerts.buttons["断开连接"].tap()
            } else {
                app.buttons["native.sessionSettings"].tap()
                let exit = app.buttons["断开连接"]
                for _ in 0..<3 { if exit.isHittable { break }; app.swipeUp() }
                exit.tap()
                app.alerts.buttons["断开连接"].tap()
            }
            XCTAssertTrue(connect.waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["Recent sessions"].exists)
            XCTAssertFalse(app.buttons["Connection Tab 1 of 2"].exists)
        }
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native home after disconnect and foreground"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    @MainActor
    func testOriginalGestureHelpUsesTwoFingerCanvasAndThreeFingerWheel() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap(); app.buttons["手势说明"].tap()
        let modes = app.segmentedControls["native.gestureMode"]
        for mode in ["鼠标", "直接触控"] {
            modes.buttons[mode].tap()
            let original = app.staticTexts["双指直接同向移动画布，无需先捏合缩放"]
            for _ in 0..<4 { if original.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(original.exists)
            XCTAssertTrue(app.staticTexts["三指上下滑动，使用经典滚轮手势"].exists)
            app.swipeDown()
        }
        modes.buttons["新直接触控"].tap()
        let modern = app.staticTexts["双指同向上下滑动，画面内外均可"]
        for _ in 0..<4 { if modern.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(modern.exists)
    }
    @MainActor
    func testEmbeddedTailscaleSettingsAreNativeAndDoNotRequireVPN() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO", "-native.tailscale.enabled", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        let entry = app.buttons["native.tailscaleSettings"]
        for _ in 0..<5 { if entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap()
        XCTAssertTrue(app.switches["native.tailscaleEnabled"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["native.tailscaleEnabled"].value as? String, "0")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "未启用", "未启用")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "不创建系统 VPN")).firstMatch.exists)
    }
    @MainActor
    func testProxyURLInputShowsLatencyFailureWithoutSaving() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        let advanced = app.buttons["高级设置"]
        for _ in 0..<7 { if advanced.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(advanced.isHittable); advanced.tap()
        app.buttons["网络代理"].tap()
        let address = app.textFields["native.proxyAddress"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        address.tap()
        if let old = address.value as? String, old != "proxy.example.com:1080", !old.isEmpty {
            address.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        address.typeText("http://127.0.0.1:1/\n")
        let test = app.buttons["native.testProxyLatency"]
        if !test.isHittable { app.swipeUp() }
        test.tap()
        XCTAssertTrue(app.staticTexts["连接失败"].waitForExistence(timeout: 10))
        XCTAssertTrue(test.isEnabled)
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Native proxy address and latency"; proof.lifetime = .keepAlways; add(proof)
    }
    @MainActor
    func testHomeProjectMenuOpensSettingsAboutSection() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO", "-native.language", "zh-cn"]
        app.launch()
        let input = app.textFields["native.remoteID"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(input.frame.width, app.frame.width * 0.78)
        let navigationBar = app.navigationBars["SwiftRust"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        let menu = app.buttons["native.projectMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertTrue(navigationBar.buttons["native.projectMenu"].exists)
        menu.tap()
        XCTAssertTrue(app.buttons["关于项目"].waitForExistence(timeout: 3))
        app.buttons["关于项目"].tap()
        let version = app.descendants(matching: .any)["native.aboutVersion"].firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        XCTAssertTrue(version.isHittable)
        XCTAssertTrue(app.buttons["native.openSource"].isHittable)
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Home project menu navigates to About"; proof.lifetime = .keepAlways; add(proof)
    }

    @MainActor
    func testOpenSourcePageShowsLocalLicenseAndPendingSource() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO", "-native.language", "zh-cn"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        let entry = app.buttons["native.openSource"]
        for _ in 0..<8 { if entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["native.repository"].firstMatch.exists)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Open-Source Notices"].waitForExistence(timeout: 3))
        app.buttons["native.agpl"].tap()
        XCTAssertTrue(app.navigationBars["RustDesk"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["A license resource is missing. Please contact the distributor."].exists)
        XCTAssertTrue(app.scrollViews["native.licenseDocument"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.buttons["第三方组件声明"].exists)
        XCTAssertFalse(app.buttons["Tailscale · BSD 及依赖声明"].exists)
        app.buttons["native.licenseNotices"].tap()
        let document = app.scrollViews["native.licenseDocument"]
        XCTAssertTrue(document.waitForExistence(timeout: 10))
        document.swipeUp()
        XCTAssertFalse(app.buttons["native.nextLicensePage"].exists)
        document.swipeUp()
        XCTAssertTrue(app.scrollViews["native.licenseDocument"].exists)
        XCTAssertTrue(app.buttons["Export License"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["native.licenseNotices"].waitForExistence(timeout: 5))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "SwiftRust compact notices and responsive document navigation"; proof.lifetime = .keepAlways; add(proof)
    }
    @MainActor
    func testDisconnectSettingsIncludeBackgroundTimeout() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        let entry = app.buttons["native.disconnectSettings"]
        for _ in 0..<4 { if entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable)
        entry.tap()
        XCTAssertTrue(app.switches["native.skipDisconnectConfirmation"].waitForExistence(timeout: 3))
        app.buttons["native.backgroundDisconnectDelay"].tap()
        XCTAssertTrue(app.buttons["立即断开"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["10 秒"].exists)
        XCTAssertTrue(app.buttons["30 秒"].exists)
        XCTAssertTrue(app.buttons["1 分钟"].exists)
        XCTAssertTrue(app.buttons["系统允许的最长时间"].exists)
        app.buttons["系统允许的最长时间"].tap()
    }
    @MainActor
    func testAppIconSwitchPersistsAndRestoresOrange() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO"]
        func openIcons() {
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
            app.tabBars.buttons["设置"].tap()
            let entry = app.buttons["native.appIconSettings"]
            for _ in 0..<5 { if entry.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(entry.isHittable)
            entry.tap()
        }
        func dismissIconNotice() {
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            if app.alerts.firstMatch.waitForExistence(timeout: 2) {
                app.alerts.firstMatch.buttons.firstMatch.tap()
            } else if springboard.alerts.firstMatch.exists {
                springboard.alerts.firstMatch.buttons.firstMatch.tap()
            }
        }
        app.launch(); openIcons()
        app.buttons["native.appIcon.blue"].tap()
        dismissIconNotice()
        XCTAssertTrue(app.buttons["native.appIcon.blue"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND value == %@", "native.appIcon.blue", "已选中")).firstMatch.waitForExistence(timeout: 10))
        app.terminate(); app.launch(); openIcons()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND value == %@", "native.appIcon.blue", "已选中")).firstMatch.waitForExistence(timeout: 10))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "App icon selection"; proof.lifetime = .keepAlways; add(proof)
        for variant in ["whiteorange", "whiteblue"] {
            let identifier = "native.appIcon." + variant
            app.buttons[identifier].tap()
            dismissIconNotice()
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND value == %@", identifier, "已选中")).firstMatch.waitForExistence(timeout: 10))
        }
        app.buttons["native.appIcon.orange"].tap()
        dismissIconNotice()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND value == %@", "native.appIcon.orange", "已选中")).firstMatch.waitForExistence(timeout: 10))
    }
    @MainActor
    func testCustomShortcutEditorSavesAcrossAppRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "NO"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["设置"].tap()
        app.buttons["native.customShortcuts"].tap()
        let haptics = app.switches["native.keyboardHaptics"]
        XCTAssertEqual(haptics.value as? String, "1")
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(haptics.value as? String, "0")
        app.buttons["添加快捷键"].tap()
        let name = app.textFields["native.shortcutName"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("Test Shortcut")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["Test Shortcut"].waitForExistence(timeout: 3))
        app.terminate(); app.launch()
        app.tabBars.buttons["设置"].tap()
        app.buttons["native.customShortcuts"].tap()
        XCTAssertEqual(haptics.value as? String, "0")
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let saved = app.staticTexts["Test Shortcut"]
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Custom shortcut settings"; proof.lifetime = .keepAlways; add(proof)
        saved.swipeLeft()
        let delete = app.buttons["Delete"].exists ? app.buttons["Delete"] : app.buttons["删除"]
        delete.tap()
        XCTAssertTrue(saved.waitForNonExistence(timeout: 3))
    }
    @MainActor
    func testHomeDockSwitchesSections() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-native-appearance", "light"]
        app.launch()
        let dock = app.tabBars.firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["手势说明"].exists)
        XCTAssertFalse(dock.buttons["搜索"].exists)
        XCTAssertFalse(app.navigationBars["主页"].exists)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["连接选项"].exists)
        XCTAssertEqual(app.textFields["native.remoteID"].placeholderValue, "远程 ID")
        for section in ["收藏", "设置"] {
            let button = dock.buttons[section]
            XCTAssertTrue(button.isHittable)
            button.tap()
            if section == "设置" { XCTAssertFalse(dock.isHittable) } else { XCTAssertTrue(button.isSelected) }
            if section == "主页" { XCTAssertFalse(app.searchFields.firstMatch.exists) }
        }
        XCTAssertTrue(dock.isHittable)
        dock.buttons["主页"].tap()
        XCTAssertTrue(app.buttons["native.connect"].waitForExistence(timeout: 3))
        let scan = app.buttons["native.scanQR"]
        XCTAssertTrue(scan.isHittable)
        scan.tap()
        XCTAssertTrue(app.staticTexts["二维码连接"].firstMatch.waitForExistence(timeout: 3))
        let cancelScan = app.buttons["取消"]
        XCTAssertTrue(cancelScan.isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(cancelScan.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(cancelScan.frame.maxX, app.frame.maxX - 40)
        XCTAssertTrue(cancelScan.isHittable)
        cancelScan.tap()
        XCUIDevice.shared.orientation = .portrait
        let homeLogin = app.buttons["native.homeLogin"]
        XCTAssertTrue(homeLogin.exists)
        homeLogin.tap()
        XCTAssertTrue(app.textFields["native.accountUsername"].waitForExistence(timeout: 3))
        app.buttons["完成"].tap()
        dock.buttons["设置"].tap()
        let showLogin = app.switches["native.showHomeLogin"]
        XCTAssertTrue(showLogin.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["图标与开源许可"].exists)
        showLogin.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(showLogin.value as? String, "0")
        XCTAssertTrue(dock.isHittable)
        dock.buttons["主页"].tap()
        XCTAssertTrue(homeLogin.waitForNonExistence(timeout: 3))
        dock.buttons["设置"].tap()
        app.buttons["native.settingsLogin"].tap()
        XCTAssertTrue(app.textFields["native.accountUsername"].waitForExistence(timeout: 3))
        app.buttons["完成"].tap()
        showLogin.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(dock.isHittable)
        dock.buttons["主页"].tap()
        XCTAssertTrue(homeLogin.waitForExistence(timeout: 3))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Home bottom Dock"
        proof.lifetime = .keepAlways
        add(proof)
    }

    @MainActor
    func testPeerIconAppearancePersistsAndResets() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-native-appearance", "light"]
        app.launch()
        func openAppearance() {
            app.tabBars.buttons["设置"].tap()
            let entry = app.buttons["native.peerAppearanceSettings"]
            for _ in 0..<3 { if entry.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(entry.isHittable); entry.tap()
        }
        openAppearance()
        let peer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.peerAppearance.")).firstMatch
        guard peer.exists else { throw XCTSkip("No saved device is available for appearance editing") }
        peer.tap()
        app.buttons["绿色"].tap()
        app.buttons["Windows"].tap()
        XCTAssertTrue(app.buttons["绿色"].isSelected)
        XCTAssertTrue(app.buttons["Windows"].isSelected)
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Device icon and color editor"; proof.lifetime = .keepAlways; add(proof)
        app.terminate(); app.launch()
        openAppearance()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.peerAppearance.")).firstMatch.tap()
        XCTAssertTrue(app.buttons["绿色"].isSelected)
        XCTAssertTrue(app.buttons["Windows"].isSelected)
        let reset = app.buttons["native.resetPeerAppearance"]
        for _ in 0..<3 { if reset.isHittable { break }; app.swipeUp() }
        reset.tap()
        app.swipeDown()
        XCTAssertFalse(app.buttons["绿色"].isSelected)
        XCTAssertFalse(app.buttons["Windows"].isSelected)
    }

    @MainActor
    func testDarkAppearanceSurfaces() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-native-appearance", "dark"]
        app.launch()
        func proof(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertTrue(app.buttons["native.connect"].waitForExistence(timeout: 10))
        proof("Dark home")
        let peerMenu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.peerMenu.")).firstMatch
        if peerMenu.exists {
            peerMenu.tap()
            for title in ["远程控制", "传输文件", "查看摄像头", "终端", "重命名", "删除记录"] { XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 3)) }
            proof("Dark device menu")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.12)).tap()
        }
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["native.settingsLogin"].waitForExistence(timeout: 3))
        proof("Dark settings")
        app.buttons["native.settingsLogin"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 3))
        if app.textFields["native.accountUsername"].exists {
            XCTAssertTrue(app.textFields["native.accountUsername"].isEnabled)
        }
        proof("Dark account")
        app.buttons["完成"].tap()
        app.buttons["手势说明"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 3))
        let gestureModes = app.segmentedControls["native.gestureMode"]
        XCTAssertTrue(gestureModes.exists)
        XCTAssertEqual(gestureModes.buttons.element(boundBy: 1).label, "新直接触控")
        gestureModes.buttons["鼠标"].tap()
        XCTAssertTrue(app.staticTexts["经典鼠标模式：单指移动指针，双击后移动拖动。"].exists)
        gestureModes.buttons["直接触控"].tap()
        XCTAssertTrue(app.staticTexts["在远程画面内按住目标滑动，移出画面或抬手释放"].exists)
        XCTAssertTrue(app.staticTexts["单指长按"].exists)
        proof("Dark direct touch help")
        gestureModes.buttons["新直接触控"].tap()
        XCTAssertTrue(app.staticTexts["新直接触控：保留直接定位和拖动，改用双指滚动。"].exists)
        proof("Dark new direct touch help")
        gestureModes.buttons["触控板"].tap()
        XCTAssertTrue(app.staticTexts["触控板：单指移动指针，双指滚动，长按拖动。"].exists)
        proof("Dark gesture help")
        app.buttons["完成"].tap()
        app.buttons["高级设置"].tap()
        proof("Dark advanced settings")
        app.terminate()
        for kind in ["terminal", "files", "desktop"] {
            app.launchArguments = ["-native-appearance", "dark", "-NativeUITestImmersive", "YES", "-NativeUITestSessionKind", kind]
            app.launch()
            if kind == "terminal" {
                XCTAssertTrue(app.buttons["终端菜单"].waitForExistence(timeout: 5))
            } else if kind == "files" {
                XCTAssertTrue(app.buttons["上传文件"].waitForExistence(timeout: 5))
            } else {
                XCTAssertTrue(app.buttons["native.shortcutsKeyboard"].waitForExistence(timeout: 5))
            }
            proof("Dark \(kind)")
            if kind == "desktop" {
                app.buttons["native.shortcutsKeyboard"].tap()
                XCTAssertTrue(app.buttons["收起远程键盘"].waitForExistence(timeout: 3))
                proof("Dark remote keyboard")
            }
            app.terminate()
        }
    }

    @MainActor
    func testSavedPeerDestructiveMenuActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-native.language", "zh-cn", "-native.launch-restore", "NO", "-NativeUITestImmersive", "NO"]
        app.launch()
        let menu = app.buttons["native.peerMenu.native-destructive-regression"]
        guard menu.waitForExistence(timeout: 10) else { throw XCTSkip("Requires the isolated native-destructive-regression peer fixture") }
        menu.tap()
        app.buttons["清除已保存的密码"].tap()
        let forget = app.alerts["清除已保存的密码？"]
        XCTAssertTrue(forget.waitForExistence(timeout: 5))
        forget.buttons["清除密码"].tap()
        menu.tap()
        XCTAssertFalse(app.buttons["清除已保存的密码"].isEnabled)
        app.buttons["删除记录"].tap()
        let remove = app.alerts["删除设备记录？"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.buttons["删除记录"].tap()
        XCTAssertFalse(menu.waitForExistence(timeout: 2))
        app.terminate(); app.launch()
        XCTAssertFalse(menu.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSavedDeviceMenuAndNativeTerminal() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.peerMenu.")).firstMatch
        guard menu.waitForExistence(timeout: 10) else { throw XCTSkip("No saved device exists in this simulator") }
        menu.tap()
        for title in ["远程控制", "传输文件", "查看摄像头", "终端", "请求批准", "强制中继连接", "重命名", "清除已保存的密码", "删除记录"] {
            XCTAssertTrue(app.buttons[title].exists || app.switches[title].exists || app.staticTexts[title].exists, title)
        }
        app.terminate()
        app.launchArguments = ["-NativeUITestImmersive", "YES", "-NativeUITestSessionKind", "terminal"]
        app.launch()
        let canvas = app.descendants(matching: .any).matching(identifier: "native.terminalCanvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "native.floatingControls").firstMatch.exists)
        XCTAssertFalse(app.buttons["Ctrl-C"].isEnabled)
        XCTAssertEqual(canvas.frame.width, app.frame.width, accuracy: 1)
        app.buttons["新增标签页"].tap()
        let secondTab = app.buttons["native.terminalTab.2"]
        XCTAssertTrue(secondTab.waitForExistence(timeout: 3))
        secondTab.press(forDuration: 1)
        XCTAssertTrue(app.alerts["重命名标签"].waitForExistence(timeout: 3))
        let name = app.alerts.textFields.firstMatch
        name.tap(); name.typeText("Logs")
        app.alerts.buttons["保存"].tap()
        XCTAssertTrue(secondTab.label.contains("Logs"))
        app.buttons["native.terminalTab.1"].tap()
        XCTAssertTrue(app.buttons["native.terminalTab.1"].isSelected)
        app.buttons["终端菜单"].tap()
        XCTAssertTrue(app.buttons["增大字号"].exists)
        app.buttons["增大字号"].tap()
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Native terminal layout (disconnected preview)"
        proof.lifetime = .keepAlways
        add(proof)
        app.buttons["终端菜单"].tap()
        app.buttons["显示键盘"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let accessoryEsc = app.buttons.matching(identifier: "Esc").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(accessoryEsc)
        XCTAssertEqual(app.buttons.matching(identifier: "Esc").allElementsBoundByIndex.filter { $0.isHittable }.count, 1)
        XCTAssertLessThanOrEqual(try XCTUnwrap(accessoryEsc).frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        let keyboardProof = XCTAttachment(screenshot: app.screenshot())
        keyboardProof.name = "Terminal glass shortcuts above keyboard"; keyboardProof.lifetime = .keepAlways; add(keyboardProof)
        app.buttons["终端菜单"].tap()
        app.buttons["隐藏键盘"].tap()
        app.buttons["断开终端连接"].tap()
        app.buttons.matching(identifier: "断开连接").firstMatch.tap()
        XCTAssertTrue(app.buttons["native.connect"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEverySessionKindUsesCentralDisconnectConfirmation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        for kind in ["desktop", "terminal", "files", "camera"] {
            app.launchArguments = ["-NativeUITestImmersive", "YES", "-NativeUITestSessionKind", kind]
            app.launch()
            if kind == "desktop" || kind == "camera" {
                XCTAssertTrue(app.buttons["native.sessionSettings"].waitForExistence(timeout: 5))
                app.buttons["native.sessionSettings"].tap()
            }
            let exit = app.buttons[kind == "terminal" ? "断开终端连接" : kind == "files" ? "断开文件连接" : "断开连接"]
            for _ in 0..<4 { if exit.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(exit.waitForExistence(timeout: 5))
            exit.tap()
            let alert = app.alerts["断开连接？"]
            XCTAssertTrue(alert.waitForExistence(timeout: 3))
            XCTAssertLessThan(abs(alert.frame.midY - app.frame.midY), app.frame.height * 0.2)
            alert.buttons["取消"].tap()
            if kind == "desktop" || kind == "camera" { app.buttons["native.sessionSettings"].tap() }
            XCTAssertTrue(exit.exists)
            exit.tap()
            app.alerts.buttons["断开连接"].tap()
            XCTAssertTrue(app.buttons["native.connect"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testPointerMovementSpeedPersistsAndResets() {
        let app = XCUIApplication()
        app.launch()
        func openPointerSettings() {
            app.tabBars.buttons["设置"].tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "鼠标指针,")).firstMatch.tap()
            XCTAssertTrue(app.sliders["native.pointerSpeed"].waitForExistence(timeout: 3))
        }
        openPointerSettings()
        app.buttons["native.resetPointerSpeed"].tap()
        let slider = app.sliders["native.pointerSpeed"]
        let baseline = slider.value as? String
        slider.adjust(toNormalizedSliderPosition: 0.7)
        let changed = slider.value as? String
        XCTAssertNotEqual(changed, baseline)
        app.terminate(); app.launch()
        openPointerSettings()
        XCTAssertEqual(app.sliders["native.pointerSpeed"].value as? String, changed)
        app.buttons["native.resetPointerSpeed"].tap()
        XCTAssertEqual(app.sliders["native.pointerSpeed"].value as? String, baseline)
    }
    @MainActor
    func testScrollSpeedPersistsAndResets() {
        let app = XCUIApplication()
        app.launch()
        func openScrollSettings() {
            app.tabBars.buttons["设置"].tap()
            app.buttons["native.scrollSettings"].tap()
            XCTAssertTrue(app.sliders["native.scrollSpeed"].waitForExistence(timeout: 3))
        }
        openScrollSettings()
        app.buttons["native.resetScrollSpeed"].tap()
        let slider = app.sliders["native.scrollSpeed"]
        let baseline = slider.value as? String
        slider.adjust(toNormalizedSliderPosition: 0.7)
        let changed = slider.value as? String
        XCTAssertNotEqual(changed, baseline)
        app.terminate(); app.launch()
        openScrollSettings()
        XCTAssertEqual(app.sliders["native.scrollSpeed"].value as? String, changed)
        app.buttons["native.resetScrollSpeed"].tap()
        XCTAssertEqual(app.sliders["native.scrollSpeed"].value as? String, baseline)
    }
    @MainActor
    func testControlInputAdjustmentsUseCompactGlassPopup() {
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "YES", "-native.fit-phone-window", "YES"]
        app.launch()
        app.buttons["native.sessionSettings"].tap()
        app.buttons["控制模式"].tap()
        app.buttons["指针与滚动"].tap()
        let popup = app.descendants(matching: .any).matching(identifier: "native.inputAdjustment").firstMatch
        XCTAssertTrue(popup.waitForExistence(timeout: 3))
        app.buttons["native.resetInputAdjustment"].tap()
        let sliders = ["native.inputPointerSize", "native.inputPointerSpeed", "native.inputScrollSpeed"]
        let defaults = sliders.map { app.sliders[$0].value as? String }
        for id in sliders { XCTAssertTrue(app.sliders[id].isHittable); app.sliders[id].adjust(toNormalizedSliderPosition: 0.65) }
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Compact glass pointer and scroll adjustment"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["native.resetInputAdjustment"].tap()
        XCTAssertEqual(sliders.map { app.sliders[$0].value as? String }, defaults)
        app.buttons["native.closeInputAdjustment"].tap()
        XCTAssertTrue(popup.waitForNonExistence(timeout: 3))
        app.buttons["native.sessionSettings"].tap()
        app.buttons["显示画面"].tap()
        app.buttons["分辨率"].tap()
        XCTAssertFalse(app.switches["native.fitPhoneWindow"].exists)
        XCTAssertFalse(app.buttons["适配手机窗口"].exists)
        let resolutionPopup = app.descendants(matching: .any).matching(identifier: "native.resolutionAdjustment").firstMatch
        XCTAssertTrue(resolutionPopup.exists)
        let panel = app.descendants(matching: .any).matching(identifier: "native.resolutionPanel").firstMatch
        XCTAssertTrue(panel.exists)
        XCTAssertLessThan(panel.frame.height, app.windows.firstMatch.frame.height * 0.65)
        XCTAssertFalse(app.navigationBars["分辨率"].exists)
        XCTAssertFalse(app.staticTexts["窗口可用区域"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["native.closeResolutionAdjustment"].isHittable)
        XCTAssertLessThan(panel.frame.height, app.windows.firstMatch.frame.height - 20)
        XCUIDevice.shared.orientation = .portrait
        let resolutionProof = XCTAttachment(screenshot: app.screenshot())
        resolutionProof.name = "Compact glass resolution selector"; resolutionProof.lifetime = .keepAlways; add(resolutionProof)
        app.buttons["native.closeResolutionAdjustment"].tap()
        XCTAssertTrue(resolutionPopup.waitForNonExistence(timeout: 3))
    }
    @MainActor
    func testShortcutKeyboardResizesAcrossBothOrientations() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "YES"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        app.buttons["native.shortcutsKeyboard"].tap()
        let keyboard = app.descendants(matching: .any).matching(identifier: "native.remoteKeyboard").firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height && keyboard.frame.height <= 260 && abs(keyboard.frame.width - app.windows.firstMatch.frame.width) < 2 }
        expectation(for: landscape, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["制表"].isHittable)
        XCUIDevice.shared.orientation = .portrait
        let portrait = NSPredicate { _, _ in app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width && keyboard.frame.height > 300 && abs(keyboard.frame.width - app.windows.firstMatch.frame.width) < 2 }
        expectation(for: portrait, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["制表"].isHittable)
    }
    func testImmersiveFullWidthKeyboard() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-NativeUITestImmersive", "YES"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        let canvas = app.descendants(matching: .any).matching(identifier: "native.remoteCanvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["native.cameraControls"].exists)
        func verifyFullScreen() {
            let screen = app.windows.firstMatch.frame
            XCTAssertEqual(canvas.frame.minX, screen.minX, accuracy: 2)
            XCTAssertEqual(canvas.frame.minY, screen.minY, accuracy: 2)
            XCTAssertEqual(canvas.frame.width, screen.width, accuracy: 2)
            XCTAssertEqual(canvas.frame.height, screen.height, accuracy: 2)
            let controls = app.descendants(matching: .any).matching(identifier: "native.floatingControls").firstMatch.frame
            XCTAssertGreaterThanOrEqual(controls.minX, screen.minX)
            XCTAssertLessThanOrEqual(controls.maxX, screen.maxX)
            XCTAssertGreaterThanOrEqual(controls.minY, screen.minY)
            XCTAssertLessThanOrEqual(controls.maxY, screen.maxY)
            XCTAssertFalse(app.statusBars.firstMatch.exists)
            XCTAssertFalse(app.buttons["放大"].exists)
            XCTAssertFalse(app.buttons["缩小"].exists)
        }
        verifyFullScreen()
        XCTAssertTrue(app.buttons["native.keyboard"].exists)
        XCTAssertTrue(app.buttons["native.sessionSettings"].exists)
        XCTAssertFalse(app.buttons["native.disconnect"].exists)
        let dock = app.descendants(matching: .any).matching(identifier: "native.floatingControls").firstMatch
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(dock.frame.maxY, screen.maxY - 20)
        dock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.width * 0.1, dy: dock.frame.midY)))
        XCTAssertEqual(dock.frame.minX, screen.minX, accuracy: 3)
        dock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.width * 0.9, dy: dock.frame.midY)))
        XCTAssertEqual(dock.frame.maxX, screen.maxX, accuracy: 3)
        XCTAssertLessThanOrEqual(dock.frame.width, 149)
        XCTAssertTrue(app.buttons["native.dictation"].exists)
        app.buttons["native.keyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["native.keyboard"].label, "收起系统键盘")
        let accessoryDock = app.descendants(matching: .any).matching(identifier: "native.floatingControls").firstMatch
        XCTAssertLessThanOrEqual(accessoryDock.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        XCTAssertTrue(app.buttons["native.sessionSettings"].isHittable)
        accessoryDock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.width * 0.1, dy: accessoryDock.frame.midY)))
        XCTAssertEqual(accessoryDock.frame.minX, screen.minX, accuracy: 3)
        accessoryDock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.width * 0.9, dy: accessoryDock.frame.midY)))
        XCTAssertEqual(accessoryDock.frame.maxX, screen.maxX, accuracy: 3)
        let keyboardProof = XCTAttachment(screenshot: app.screenshot())
        keyboardProof.name = "Compact dock floating above system keyboard"; keyboardProof.lifetime = .keepAlways; add(keyboardProof)
        app.buttons["native.keyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.buttons["native.keyboard"].label, "系统键盘")
        app.buttons["native.sessionSettings"].tap()
        XCTAssertTrue(app.buttons["控制模式"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["显示画面"].exists)
        XCTAssertFalse(app.buttons["全部会话设置"].exists)
        XCTAssertLessThan(app.buttons["控制模式"].frame.minY, app.buttons["显示画面"].frame.minY)
        XCTAssertLessThan(app.buttons["显示画面"].frame.minY, app.buttons["画质与编码"].frame.minY)
        XCTAssertLessThan(app.buttons["画质与编码"].frame.minY, app.buttons["声音与访问"].frame.minY)
        XCTAssertLessThan(app.buttons["声音与访问"].frame.minY, app.buttons["断开连接"].frame.minY)
        let menuProof = XCTAttachment(screenshot: app.screenshot())
        menuProof.name = "Native session settings popup menu"; menuProof.lifetime = .keepAlways; add(menuProof)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.4)).tap()
        let keyboardButton = app.buttons["native.shortcutsKeyboard"]
        XCTAssertTrue(keyboardButton.exists)
        keyboardButton.tap()
        let keyboard = app.descendants(matching: .any).matching(identifier: "native.remoteKeyboard").firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertEqual(keyboard.frame.width, app.windows.firstMatch.frame.width, accuracy: 2)
        XCTAssertEqual(keyboard.frame.minX, app.windows.firstMatch.frame.minX, accuracy: 2)
        XCTAssertTrue(app.buttons["native.keyboardPage.0"].isSelected)
        XCTAssertTrue(app.staticTexts["制表"].isHittable, "All current common shortcuts should fit without scrolling")
        app.buttons["native.keyboardPage.3"].tap()
        XCTAssertTrue(app.buttons["native.keyboardPage.3"].isSelected)
        XCTAssertTrue(app.buttons["F12"].isHittable)
        XCTAssertFalse(app.buttons["native.keyboardPage.4"].exists)
        XCTAssertTrue(app.buttons["Home"].isHittable)
        XCTAssertTrue(app.buttons["PgDn"].isHittable)
        let navigationProof = XCTAttachment(screenshot: app.screenshot())
        navigationProof.name = "Larger keyboard symbol keys"; navigationProof.lifetime = .keepAlways; add(navigationProof)
        app.buttons["native.keyboardPage.1"].tap()
        XCTAssertTrue(app.buttons["P"].isHittable)
        XCTAssertTrue(app.buttons.matching(identifier: "Ctrl").allElementsBoundByIndex.contains { $0.isHittable })
        XCTAssertTrue(app.buttons.matching(identifier: "回车").allElementsBoundByIndex.contains { $0.isHittable })
        let portraitProof = XCTAttachment(screenshot: app.screenshot())
        portraitProof.name = "Compact paged shortcut keyboard"; portraitProof.lifetime = .keepAlways; add(portraitProof)
        app.buttons["收起远程键盘"].tap()
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        expectation(for: landscape, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        verifyFullScreen()
        XCTAssertTrue(keyboardButton.waitForExistence(timeout: 3))
        keyboardButton.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertEqual(keyboard.frame.width, app.windows.firstMatch.frame.width, accuracy: 2)
        XCTAssertEqual(keyboard.frame.minX, app.windows.firstMatch.frame.minX, accuracy: 2)
        XCTAssertEqual(keyboard.frame.height, max(240, app.windows.firstMatch.frame.height * 0.45), accuracy: 2)
        XCTAssertTrue(app.staticTexts["制表"].isHittable)
        app.buttons["native.keyboardPage.1"].tap()
        XCTAssertTrue(app.buttons["P"].isHittable)
        XCTAssertTrue(app.buttons.matching(identifier: "Ctrl").allElementsBoundByIndex.contains { $0.isHittable })
        XCTAssertTrue(app.buttons.matching(identifier: "回车").allElementsBoundByIndex.contains { $0.isHittable })
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Immersive full-width keyboard"
        proof.lifetime = .keepAlways
        add(proof)

    }

}
