import Foundation

enum State {
    case NotInitialized
    case Initialized
}

public typealias PasswordlessCallback = (_ result: Result<AuthToken, ReachFiveError>) -> Void

//TODO
// Tester One-tap account upgrade : https://developer.apple.com/videos/play/wwdc2020/10666/
// Tester le MFA avec "Securing Logins with iCloud Keychain Verification Codes" https://developer.apple.com/documentation/authenticationservices/securing_logins_with_icloud_keychain_verification_codes
// Apparemment les custom scheme sont dépréciés et il faudrait utiliser les "Universal Links" : https://developer.apple.com/ios/universal-links/
/// ReachFive identity SDK
public class ReachFive: NSObject {
    var passwordlessCallback: PasswordlessCallback? = nil
    var state: State = .NotInitialized
    public let sdkConfig: SdkConfig
    let providersCreators: Array<ProviderCreator>
    let reachFiveApi: ReachFiveApi
    var providers: [Provider] = []
    internal var scope: [String] = []
    internal var clientConfig: ClientConfigResponse? = nil
    public let storage: Storage
    let credentialManager: CredentialManager
    public let pkceKey = "PASSWORDLESS_PKCE"
    
    public init(sdkConfig: SdkConfig, providersCreators: Array<ProviderCreator> = [], storage: Storage? = nil) {
        self.sdkConfig = sdkConfig
        self.providersCreators = providersCreators
        self.reachFiveApi = ReachFiveApi(sdkConfig: sdkConfig)
        self.storage = storage ?? UserDefaultsStorage()
        self.credentialManager = CredentialManager(reachFiveApi: reachFiveApi)
    }
    
    public override var description: String {
        """
        Config: domain=\(sdkConfig.domain), clientId=\(sdkConfig.clientId)
        Providers: \(providers)
        Scope: \(scope.joined(separator: " "))
        """
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        interceptPasswordless(url)
        for provider in providers {
            let _ = provider.application(app, open: url, options: options)
        }
        return true
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initialize().onSuccess { providers in
            for provider in providers {
                let _ = provider.application(application, didFinishLaunchingWithOptions: launchOptions)
            }
        }
        
        return true
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        for provider in providers {
            let _ = provider.applicationDidBecomeActive(application)
        }
    }
    
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        for provider in providers {
            let _ = provider.application(application, continue: userActivity, restorationHandler: restorationHandler)
        }
        return true
    }
}
