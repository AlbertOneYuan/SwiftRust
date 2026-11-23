// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-22.
// SPDX-License-Identifier: AGPL-3.0-only
import PostHog
import Foundation

enum NativeTraffic {
    static let enabledKey = "native.anonymous-analytics"
    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    private static var projectToken: String { FeedbackConfig.appKey }
    private static let host = "https://apps.air.build/traffic"

    enum Screen: String, CaseIterable {
        case home = "Home", favorites = "Favorites", settings = "Settings"
    }

    static func configuration() -> PostHogConfig {
        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.personProfiles = .never
        config.setDefaultPersonProperties = false
        config.disableGeoIp = true
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.captureElementInteractions = false
        config.captureSwiftUIElementInteractions = false
        config.captureAutocaptureElementText = false
        config.rageClickConfig.enabled = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.sessionReplay = false
        config.surveys = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.errorTrackingConfig.autoCapture = false
        config.errorTrackingConfig.exceptionSteps.enabled = false
        config.tracingHeaders = nil
        config.debug = false
        config.logs.setBeforeSend { _ in nil }
        config.setBeforeSend { event in
            guard let properties = NativeTraffic.properties(event: event.event, values: event.properties) else { return nil }
            event.properties = properties
            return event
        }
        return config
    }

    // A positive allowlist prevents future SDK defaults from collecting UI or connection content.
    static func properties(event: String, values: [String: Any]) -> [String: Any]? {
        switch event {
        case "$screen":
            guard let name = values["$screen_name"] as? String, Screen(rawValue: name) != nil else { return nil }
        case "Application Installed", "Application Updated", "Application Opened", "Application Backgrounded": break
        default: return nil
        }
        let allowed: Set<String> = ["$screen_name", "$session_id", "$lib", "$lib_version",
            "$app_version", "$app_build", "$os_name", "$os_version", "$device_manufacturer",
            "$device_model", "$device_type", "$is_emulator", "$is_testflight", "$is_sideloaded",
            "previous_version", "previous_build", "from_background"]
        var result = values.filter { allowed.contains($0.key) }
        if let name = result["$screen_name"] as? String, Screen(rawValue: name) == nil { result.removeValue(forKey: "$screen_name") }
        result["$process_person_profile"] = false
        result["$geoip_disable"] = true
        return result
    }

    static func start() {
        guard enabled, !projectToken.isEmpty else { return }
        PostHogSDK.shared.setup(configuration())
        PostHogSDK.shared.optIn()
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if enabled { start() }
        else {
            PostHogSDK.shared.optOut()
            // close also stops queue timers and remote configuration while analytics is disabled.
            PostHogSDK.shared.close()
        }
    }

    static func screen(_ screen: Screen) {
        guard enabled, !projectToken.isEmpty else { return }
        PostHogSDK.shared.screen(screen.rawValue)
    }
}
