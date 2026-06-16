import UIKit
import Reach5
import Reach5Google
import Reach5Facebook
//import Reach5WeChat

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let sdkRemote = SdkConfig(
        domain: "integ-qa-fonctionnelle.reach5.net",
        clientId: "9DKRdQyDLpaJqQQQAR9K"
    )

    static let sdkLocal = SdkConfig(
        domain: "local-sandbox.og4.me",
        clientId: "9DKRdQyDLpaJqQQQAR9K"
    )

    static let local = SecureStorage()
    static let shared = SecureStorage(group: Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String + "com.reach5.SharedItems")

    let reachfive = ReachFive(sdkConfig: sdkLocal,
                              providersCreators: [
                                FacebookProvider(variant: "variant_1"),
                                GoogleProvider(variant: "one_tap"),
                                // TODO: renseigner le name (et la variant) du provider à retour en lien universel,
                                // tels que configurés côté Reach5. Le host/path du lien sont déduits de la config serveur.
                                UniversalLinkProviderCreator(name: "monProvider", variant: "default", reachfive: AppDelegate.reachfive()),
                                /*WeChatProvider()*/
                              ],
                              storage: local)

    static func reachfive() -> ReachFive {
        let app = UIApplication.shared.delegate as! AppDelegate
        return app.reachfive
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return reachfive.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("application(_:configurationForConnecting:\(connectingSceneSession):options:\(options)")
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

extension UIViewController {
    func goToProfile(token: AuthToken) {
        print("goToProfile")

        AppDelegate.local.setToken(token)
        AppDelegate.shared.setToken(token)

        guard let profileController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Profile") as? ProfileViewController else {
            print("did not find ProfileViewController")
            return
        }

        profileController.authToken = token
        if let top = navigationController?.topViewController, let _ = top as? ProfileViewController {
            return
        }
        navigationController?.pushViewController(profileController, animated: true)
    }
}
