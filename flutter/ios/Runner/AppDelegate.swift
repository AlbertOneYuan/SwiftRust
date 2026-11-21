import UIKit
import AVFoundation

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do { try AVAudioSession.sharedInstance().setCategory(.ambient) }
        catch { NSLog("Audio session configuration failed: %@", error.localizedDescription) }
        if #available(iOS 17.0, *) { NativeHomeQuickActions.refresh() }
        return true
    }
}
