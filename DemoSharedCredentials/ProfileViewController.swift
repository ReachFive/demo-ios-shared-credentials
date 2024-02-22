import UIKit
import IdentitySdkCore

class ProfileViewController: UIViewController {
    var authToken: AuthToken!
    
    @IBOutlet var emailText: UITextView!
    @IBOutlet var phoneText: UITextView!
    @IBOutlet var loginText: UITextView!
    
    override func viewWillAppear(_ animated: Bool) {
        print("ProfileController.viewWillAppear")
//        guard let authToken else {
//            print("not logged in")
//            return
//        }
        
        AppDelegate.reachfive()
            .getProfile(authToken: authToken)
            .onSuccess { profile in
                if let email = profile.email {
                    self.emailText.text = email
//                    self.emailLabel.text?.append(profile.emailVerified == true ? " ✔︎" : " ✘")
                }
                if let phoneNumber = profile.phoneNumber {
                    self.phoneText.text = phoneNumber
//                    self.phoneNumberLabel.text?.append(profile.phoneNumberVerified == true ? " ✔︎" : " ✘")
                }
//                self.customIdentifierLabel.text = profile.customIdentifier
                if let loginSummary = profile.loginSummary, let lastLogin = loginSummary.lastLogin {
                    self.loginText.text = self.format(date: lastLogin).appending(" : ").appending(loginSummary.lastProvider ?? "")
                }
            }
            .onFailure { error in
                // the token is probably expired, but it is still possible that it can be refreshed
                print("getProfile error = \(error.message())")
            }
        
        super.viewWillAppear(animated)
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
        AppDelegate.local.removeToken { () -> Void in
            AppDelegate.reachfive().logout().onComplete { res in
                print(res)
            }
        }
        navigationController?.popViewController(animated: true)
    }
}
