import UIKit
import Reach5

class ProfileViewController: UIViewController {
    var authToken: AuthToken!
    
    @IBOutlet var emailText: UITextView!
    @IBOutlet var phoneText: UITextView!
    @IBOutlet var loginText: UITextView!
    
    override func viewWillAppear(_ animated: Bool) {
        print("ProfileController.viewWillAppear")
        Task {
            do {
                let profile = try await AppDelegate.reachfive().getProfile(authToken: authToken)
                affiche(profile: profile)
            } catch {
                
                // the token is probably expired, but it is still possible that it can be refreshed
                print("getProfile error = \(error.localizedDescription)")
                let AuthToken = try await AppDelegate.reachfive().refreshAccessToken(authToken: self.authToken)
                AppDelegate.local.setToken(AuthToken)
                AppDelegate.shared.setToken(AuthToken)
                
                do {
                    let profile = try await AppDelegate.reachfive().getProfile(authToken: AuthToken)
                    self.affiche(profile: profile)
                } catch {
                    print("getProfile error = \(error.localizedDescription)")
                }
            }
        }
        
        super.viewWillAppear(animated)
    }
    
    @MainActor
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
            Task {
                let _ = try? await AppDelegate.reachfive().logout()
                print("removed last shared token")
            }
        }
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func logoutAll(_ sender: Any) {
        AppDelegate.local.removeAllTokens()
        AppDelegate.shared.removeAllTokens()
    }
}
