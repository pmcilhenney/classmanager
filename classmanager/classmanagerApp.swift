import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        print("[Push] registered device token: \(tokenParts.joined())")
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[Push] failed to register: \(error.localizedDescription)")
        #endif
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }
}

@main
struct classmanagerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - App wiring (no type re-definitions here)
    private let config: AppConfig
    private let jotform: JotFormClient
    private let flexi: FlexiQuizClient

    init() {
        // Try your existing AppConfig loader(s). Keep whichever one your project actually has.
        // ❗ Pick the one you have in your codebase and delete the other line:

        // 1) If you have this:
        // let loadedConfig = AppConfig.fromInfoPlist()

        // 2) Otherwise, if your project uses this older helper:
        // let loadedConfig = AppConfig.fromPlist()

        // 3) If neither helper exists but you have a memberwise init,
        //    you can construct it manually from Info.plist here.
        //    (Uncomment and map your actual keys if needed.)
        // let loadedConfig = AppConfig(
        //     logoAsset: Bundle.main.object(forInfoDictionaryKey: "LOGO_ASSET") as? String ?? "gcems_logo",
        //     jotformApiKey: Bundle.main.object(forInfoDictionaryKey: "JOTFORM_API_KEY") as? String ?? "",
        //     checkinFormId: Bundle.main.object(forInfoDictionaryKey: "CHECKIN_FORM_ID") as? String ?? "",
        //     checkoutFormId: Bundle.main.object(forInfoDictionaryKey: "CHECKOUT_FORM_ID") as? String ?? "",
        //     skillsFormId: Bundle.main.object(forInfoDictionaryKey: "SKILLS_FORM_ID") as? String ?? "",
        //     flexiEmailDomain: Bundle.main.object(forInfoDictionaryKey: "FLEXI_EMAIL_DOMAIN") as? String ?? "",
        //     flexiMap: [
        //         "RefresherA": Bundle.main.object(forInfoDictionaryKey: "FLEXI_REF_A") as? String ?? "",
        //         "RefresherB": Bundle.main.object(forInfoDictionaryKey: "FLEXI_REF_B") as? String ?? "",
        //         "RefresherC": Bundle.main.object(forInfoDictionaryKey: "FLEXI_REF_C") as? String ?? ""
        //     ]
        // )

        // Default: try the common modern helper; if it doesn’t exist, switch to fromPlist() above.
        let loadedConfig = AppConfig.fromPlist()

        self.config = loadedConfig
        self.jotform = JotFormClient(apiKey: loadedConfig.jotformApiKey)
        // Build FlexiQuiz client using its own config loader you already implemented
        // (If your FlexiQuizClient uses a different initializer, swap just this line.)
        self.flexi = FlexiQuizClient(config: .fromInfoPlist())
    }

    var body: some Scene {
        WindowGroup {
            if UIDevice.current.userInterfaceIdiom == .phone {
                InstructorPhoneView(
                    config: config,
                    jotform: jotform,
                    flexi: flexi
                )
            } else {
                WelcomeView(
                    config: config,
                    jotform: jotform,
                    flexi: flexi
                )
            }
        }
    }
}
