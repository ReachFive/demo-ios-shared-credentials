import UIKit
import AuthenticationServices
import Reach5

class LoginViewController: UIViewController {
    var enteringForegroung: NSObjectProtocol?

    @IBOutlet var SeConnecterAAutre: UIButton!
    @IBOutlet var SeConnecter: UIButton!
    @IBOutlet var safari: UIButton!
    @IBOutlet var Credential: UIButton!
    @IBOutlet var Identifier: UILabel!
    @IBOutlet var Reload: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        enteringForegroung = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
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
        Task { await firstPartySession() }
    }

    func firstPartySession() async {
        print("connectWithSafari")
        do {
            let token = try await AppDelegate.reachfive().webviewLogin(WebviewLoginRequest(presentationContextProvider: self))
            self.goToProfile(token: token)
        } catch {
            print(error)
        }
    }

    // For testing purposes
    func thirdPartySession() async {
        print("connectWithSafari")
        print(AppDelegate.reachfive().getProviders())
        if let provider = AppDelegate.reachfive().getProvider(name: "facebook") {
            print(type(of: provider))
            do {
                let token = try await provider.login(scope: nil, origin: "thirdPartySession", viewController: self)
                self.goToProfile(token: token)
            } catch {
                print(error)
            }
        } else {
            print("no provider")
        }
    }

    @IBAction func connectWithCredential(_ sender: Any) {
        print("connectWithCredential")
//        var types: [ModalAuthorization] = [.Password]
        var types: [ModalAuthorization] = []
        if #available(iOS 16.0, *) {
            types.append(.Passkey)
        }
        Task {
            do {
                let flow = try await AppDelegate.reachfive().login(withRequest: NativeLoginRequest(anchor: self.view.window!), usingModalAuthorizationFor: types, display: .Always)
                if case let LoginFlow.AchievedLogin(token) = flow {
                    self.goToProfile(token: token)
                }
            } catch {
                print(error)
            }
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
