import UIKit
import AVFoundation

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do { try AVAudioSession.sharedInstance().setCategory(.ambient) }
        catch { NSLog("Audio session configuration failed: %@", error.localizedDescription) }
        if #available(iOS 17.0, *) { NativeHomeQuickActions.refresh() }
        if !FeedbackConfig.appKey.isEmpty {
            AirCrashReports.start(apiKey: FeedbackConfig.appKey, endpoint: "https://apps.air.build/v1/ingest/crashes", teamID: FeedbackConfig.teamID)
        }
        NativeTraffic.start()
        return true
    }
}
