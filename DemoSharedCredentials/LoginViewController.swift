import UIKit
import IdentitySdkCore

class LoginViewController: UIViewController {

    @IBOutlet var SeConnecterAAutre: UIButton!
    @IBOutlet var SeConnecter: UIButton!
    @IBOutlet var safari: UIButton!
    @IBOutlet var Identifier: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("LoginViewController.viewWillAppear")
//        let tk: AuthToken = AuthToken(idToken: "toto", accessToken: "toto", refreshToken: "toto", tokenType: "toto", expiresIn: 100000, user: nil)
//        AppDelegate.local.save(key: "token", value: tk)
        if let token: AuthToken = AppDelegate.local.get(key: "token") {
            print("did find token on LoginViewController.viewWillAppear")
            goToProfile(token: token)
        } else if let token: AuthToken = AppDelegate.shared.get(key: "token") {
            Identifier.isHidden = false
            SeConnecter.isHidden = false
            SeConnecterAAutre.isHidden = false
            safari.isHidden = true
            
            Identifier.text = token.user?.email

        } else {
            print("token not found on LoginViewController.viewWillAppear")
            Identifier.isHidden = true
            SeConnecter.isHidden = true
            SeConnecterAAutre.isHidden = true
            safari.isHidden = false
        }
    }

    @IBAction func connectWithToken(_ sender: Any) {
        if let token: AuthToken = AppDelegate.shared.get(key: "token") {
            goToProfile(token: token)
        }
    }
    
    @IBAction func connectOther(_ sender: Any) {
        safari.isHidden = false
    }
    
    @IBAction func connectWithSafari(_ sender: Any) {
    }
}

