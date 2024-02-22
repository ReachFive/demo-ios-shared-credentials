import UIKit
import IdentitySdkCore

class ProfileViewController: UIViewController {
    var authToken: AuthToken!
    
    @IBOutlet var emailText: UITextView!
    @IBOutlet var phoneText: UITextView!
    @IBOutlet var loginText: UITextView!
    
    override func viewWillAppear(_ animated: Bool) {
        print("ProfileController.viewWillAppear")
        
        AppDelegate.reachfive()
            .getProfile(authToken: authToken)
            .onSuccess(callback: affiche)
            .onFailure { error in
                // the token is probably expired, but it is still possible that it can be refreshed
                print("getProfile error = \(error.message())")
                AppDelegate.reachfive().refreshAccessToken(authToken: self.authToken)
                    .onSuccess { AuthToken in
                        AppDelegate.local.setToken(AuthToken)
                        AppDelegate.shared.setToken(AuthToken)
                        
                        AppDelegate.reachfive()
                            .getProfile(authToken: AuthToken)
                            .onSuccess { profile in
                                self.affiche(profile: profile)
                            }
                            .onFailure { error in
                                print("getProfile error = \(error.message())")
                            }
                    }
            }
        
        super.viewWillAppear(animated)
    }
    
    private func affiche(profile: Profile) {
        if let email = profile.email {
            self.emailText.text = email
        }
        if let phoneNumber = profile.phoneNumber {
            self.phoneText.text = phoneNumber
        }
        if let loginSummary = profile.loginSummary, let lastLogin = loginSummary.lastLogin {
            self.loginText.text = self.format(date: lastLogin).appending(" : ").appending(loginSummary.lastProvider ?? "")
        }
    }
    
    private func format(date: Int) -> String {
        let lastLogin = Date(timeIntervalSince1970: TimeInterval(date / 1000))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        dateFormatter.locale = Locale(identifier: "en_GB")
        return dateFormatter.string(from: lastLogin)
    }
    
    @IBAction func logout(_ sender: Any) {
        print("logout(_:)")
        AppDelegate.local.removeToken()
        AppDelegate.shared.removeToken {
            AppDelegate.reachfive().logout().onComplete { res in
                print("removed last shared token. \(res)")
            }
        }
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func logoutAll(_ sender: Any) {
        AppDelegate.local.removeAllTokens()
        AppDelegate.shared.removeAllTokens()
    }
}
