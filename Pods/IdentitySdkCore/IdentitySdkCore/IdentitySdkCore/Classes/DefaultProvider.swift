import Foundation
import BrightFutures
import AuthenticationServices

class DefaultProvider: NSObject, Provider {
    let name: String
    
    let reachfive: ReachFive
    let providerConfig: ProviderConfig
    
    public init(reachfive: ReachFive, providerConfig: ProviderConfig) {
        self.reachfive = reachfive
        self.providerConfig = providerConfig
        self.name = providerConfig.provider
    }
    
    public func login(
        scope: [String]?,
        origin: String,
        viewController: UIViewController?
    ) -> Future<AuthToken, ReachFiveError> {
        
        guard let presentationContextProvider = viewController as? ASWebAuthenticationPresentationContextProviding else {
            return Future(error: .TechnicalError(reason: "No presenting viewController"))
        }
        
        return reachfive.webviewLogin(WebviewLoginRequest(state: "state", nonce: "nonce", scope: scope, presentationContextProvider: presentationContextProvider, origin: origin, provider: providerConfig.provider))
    }
    
    override var description: String {
        "Provider: \(providerConfig.provider)"
    }
}

extension DefaultProvider {
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        true
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        true
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    public func logout() -> Future<(), ReachFiveError> {
        Future(value: ())
    }
}

extension DefaultProvider {
    //FIXME deprecated
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        true
    }
}
