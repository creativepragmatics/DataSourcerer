import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var mainNavigationController: UINavigationController? {
        return window!.rootViewController as? UINavigationController
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
        -> Bool {

            // Skip app launch if testing
            guard ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil else {
                return false
            }

            NotificationCenter.default.post(name: Notification.Name("IBARevealRequestStart"), object: nil)
//            window = UIWindow(frame: UIScreen.main.bounds)
//            if let window = window {
//                window.rootViewController =
//                    UINavigationController(rootViewController: PublicReposRootViewController())
//                window.makeKeyAndVisible()
//            }

            return true
    }

}
