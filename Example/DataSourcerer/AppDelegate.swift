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

        window = UIWindow(frame: UIScreen.main.bounds)
        if let window = window {
            window.rootViewController =
                UINavigationController(rootViewController: PublicReposRootViewController())
            window.makeKeyAndVisible()
        }

        return true
    }

}
