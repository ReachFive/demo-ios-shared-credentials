import UIKit
import AuthenticationServices
import Reach5
import Reach5Future

class LoginViewController: UIViewController {
    var enteringForeground: NSObjectProtocol?

    @IBOutlet var SeConnecterAAutre: UIButton!
    @IBOutlet var SeConnecter: UIButton!
    @IBOutlet var safari: UIButton!
    @IBOutlet var Credential: UIButton!
    @IBOutlet var Identifier: UILabel!
    @IBOutlet var Reload: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        enteringForeground = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            print("willEnterForegroundNotification")
            self.showAndHide()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        print("LoginViewController.viewWillAppear")

        #if targetEnvironment(macCatalyst)
        Reload.isHidden = false
        #else
        Reload.isHidden = true
        #endif

        showAndHide()
    }

    private func showAndHide() {
        if let token = AppDelegate.local.getToken() {
            print("did find token on LoginViewController.viewWillAppear")
            goToProfile(token: token)
        } else if let token = AppDelegate.shared.getToken() {
            sharedLoginSheet(isHidden: false)
            localLoginSheet(isHidden: true)

            Identifier.text = token.user?.email
        } else {
            print("token not found on LoginViewController.viewWillAppear")
            sharedLoginSheet(isHidden: true)
            localLoginSheet(isHidden: false)
        }
    }

    private func sharedLoginSheet(isHidden: Bool) {
        Identifier.isHidden = isHidden
        SeConnecter.isHidden = isHidden
        SeConnecterAAutre.isHidden = isHidden
    }

    private func localLoginSheet(isHidden: Bool) {
        safari.isHidden = isHidden
        Credential.isHidden = isHidden
    }

    @IBAction func connectWithToken(_ sender: Any) {
        if let token = AppDelegate.shared.getToken() {
            goToProfile(token: token)
        }
    }

    @IBAction func connectOther(_ sender: Any) {
        localLoginSheet(isHidden: false)
    }

    @IBAction func connectWithSafari(_ sender: Any) {
        firstPartySession()
    }

    func firstPartySession() {
        print("connectWithSafari")
        AppDelegate.reachfive().webviewLogin(WebviewLoginRequest(presentationContextProvider: self))
            .onSuccess { token in
                self.goToProfile(token: token)
            }.onFailure { ReachFiveError in
                print(ReachFiveError)
            }
    }

    // For testing purposes
    func thirdPartySession() {
        print("connectWithSafari")
        print(AppDelegate.reachfive().getProviders())
        if let provider = AppDelegate.reachfive().getProvider(name: "facebook") {
            print(type(of: provider))
            provider.login(scope: nil, origin: "thirdPartySession", viewController: self)
                .onSuccess { token in
                    self.goToProfile(token: token)
                }
                .onFailure { ReachFiveError in
                    print(ReachFiveError)
                }
        } else {
            print("no provider")
        }
    }

    @IBAction func connectWithCredential(_ sender: Any) {
        print("connectWithCredential")
        var types: [ModalAuthorization] = [.Password]
        if #available(iOS 16.0, *) {
            types.append(.Passkey)
        }

        AppDelegate.reachfive().login(withRequest: NativeLoginRequest(anchor: self.view.window!), usingModalAuthorizationFor: types, display: .Always)
            .onSuccess { token in
                switch token {
                case .AchievedLogin(let authToken):
                    self.goToProfile(token: authToken)

                case .OngoingStepUp:
                    print("Step-up required")
                }
            }
            .onFailure { ReachFiveError in
                print(ReachFiveError)
            }
    }

    @IBAction func reloadData(_ sender: Any) {
        showAndHide()
    }
}

extension LoginViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window!
    }
}
