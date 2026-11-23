import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootModel: AnyObject?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var disconnectTimer: Timer?
    private var returningFromBackground = false
    private var foregroundTask: Task<Void, Never>?

    func sceneWillResignActive(_ scene: UIScene) {
        if #available(iOS 17.0, *) { NativeHomeQuickActions.refresh() }
        guard #available(iOS 17.0, *), let model = rootModel as? NativeShellModel,
              model.remoteID != nil, backgroundTask == .invalid else { return }
        model.canvas?.releaseInput()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish remote session") { [weak self] in
            self?.disconnectInBackground()
        }
    }
    func sceneDidEnterBackground(_ scene: UIScene) {
        returningFromBackground = true
        if #available(iOS 17.0, *), let model = rootModel as? NativeShellModel { model.prepareForBackground() }
        guard #available(iOS 17.0, *), let model = rootModel as? NativeShellModel, model.remoteID != nil else {
            endBackgroundSession(); return
        }
        let delay = UserDefaults.standard.object(forKey: "native.background-disconnect-delay") as? Int ?? -1
        if model.fileBrowser.isDownloading && backgroundTask != .invalid { return }
        if delay == 0 || backgroundTask == .invalid { disconnectInBackground(); return }
        if delay > 0 {
            disconnectTimer = Timer.scheduledTimer(withTimeInterval: Double(delay), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.disconnectInBackground() }
            }
        }
    }
    func sceneDidBecomeActive(_ scene: UIScene) { endBackgroundSession() }
    func sceneDidDisconnect(_ scene: UIScene) {
        endBackgroundSession(); foregroundTask?.cancel()
        if #available(iOS 17.0, *), let model = rootModel as? NativeShellModel { model.closeSession() }
        window = nil; rootModel = nil
    }
    private func disconnectInBackground() {
        guard UIApplication.shared.applicationState == .background else { endBackgroundSession(); return }
        if #available(iOS 17.0, *), let model = rootModel as? NativeShellModel {
            model.closeSession(preservingBackgroundSession: true)
        }
        endBackgroundSession()
    }
    private func endBackgroundSession() {
        disconnectTimer?.invalidate(); disconnectTimer = nil
        if backgroundTask != .invalid {
            let task = backgroundTask; backgroundTask = .invalid
            UIApplication.shared.endBackgroundTask(task)
        }
    }
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        self.window = window
        if #available(iOS 17.0, *) {
            #if SWIFTRUST_APPSTORE
            NativeTipStore.shared.start()
            #endif
            let model = NativeShellModel(window: session.persistentIdentifier)
            #if DEBUG
            if let id = UserDefaults.standard.string(forKey: "NativeUITestRemoteID") { model.idText = id }
            if UserDefaults.standard.bool(forKey: "NativeUITestImmersive") {
                model.remoteID = "ui-test"
                if let raw = UserDefaults.standard.string(forKey: "NativeUITestSessionKind"), let kind = NativeSessionKind(rawValue: raw) { model.remoteKind = kind; model.status = "未连接" }
            }
            #endif
            rootModel = model
            window.rootViewController = NativeHostingController(model: model)
        } else {
            let controller = UIViewController()
            let label = UILabel(); label.text = NativeL("此原生版本需要 iOS 17 或更新版本"); label.textAlignment = .center
            controller.view = label; window.rootViewController = controller
        }
        window.makeKeyAndVisible()
        if let item = connectionOptions.shortcutItem { performQuickAction(item, inNewScene: true) { _ in } }
        else if let url = connectionOptions.urlContexts.first?.url { open(url, inNewScene: true) }
        else if let activity = connectionOptions.userActivities.first { continueActivity(activity, inNewScene: true) }
        else if #available(iOS 17.0, *), let model = rootModel as? NativeShellModel {
            Task { @MainActor in await model.restoreOnLaunch() }
        }
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url { open(url) }
    }
    func sceneWillEnterForeground(_ scene: UIScene) {
        endBackgroundSession()
        guard #available(iOS 17.0, *), let model = rootModel as? NativeShellModel else { return }
        let shouldReconnect = returningFromBackground
        returningFromBackground = false
        foregroundTask = Task { @MainActor in
            await model.tailscale.foreground()
            guard !Task.isCancelled else { return }
            if shouldReconnect { await model.reconnectOnForeground() }
        }
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) { continueActivity(userActivity, inNewScene: false) }
    private func continueActivity(_ activity: NSUserActivity, inNewScene: Bool) {
        guard activity.activityType == NativeWindowLaunch.activityType else { return }
        if activity.userInfo?["quickAction"] as? String == "scan", #available(iOS 17.0, *), let model = rootModel as? NativeShellModel { model.sheet = .scanner; return }
        if let raw = activity.userInfo?["url"] as? String, let url = URL(string: raw) { open(url, inNewScene: inNewScene) }
    }
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        performQuickAction(shortcutItem, inNewScene: false, completion: completionHandler)
    }
    private func performQuickAction(_ item: UIApplicationShortcutItem, inNewScene: Bool, completion: @escaping (Bool) -> Void) {
        let resume = foregroundTask
        resume?.cancel(); returningFromBackground = false
        Task { @MainActor in
            await resume?.value
            guard #available(iOS 17.0, *), let model = rootModel as? NativeShellModel else { completion(false); return }
            completion(await NativeHomeQuickActions.perform(item.type, model: model, inNewScene: inNewScene))
        }
    }
    @available(iOS 17.0, *)
    func connectFromIntent(_ link: NativeLaunchLink) async throws {
        guard let model = rootModel as? NativeShellModel else { throw NativeCoreError(message: "连接窗口尚未准备好，请重试") }
        await model.openLaunchLink(link)
    }
    private func open(_ url: URL, inNewScene: Bool = false) {
        guard #available(iOS 17.0, *), let model = rootModel as? NativeShellModel else { return }
        if url.scheme?.lowercased() == "swiftrust" {
            do {
                let link = try NativeLaunchLink(url: url)
                Task { @MainActor in await model.openLaunchLink(link, inNewScene: inNewScene) }
            } catch { model.errorMessage = error.localizedDescription }
        } else if url.scheme == "rustdesk" {
            let id = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !id.isEmpty { model.idText = id }
        }
    }
}
