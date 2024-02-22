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
        
        //TEMP
        safari.isHidden = false
        
        print("LoginViewController.viewWillAppear")
//        let tk: AuthToken = AuthToken(idToken: "toto", accessToken: "toto", refreshToken: "toto", tokenType: "toto", expiresIn: 100000, user: nil)
//        AppDelegate.local.save(key: "token", value: tk)
        if let token = AppDelegate.local.getToken() {
            print("did find token on LoginViewController.viewWillAppear")
            goToProfile(token: token)
        } else if let token = AppDelegate.shared.getToken() {
            Identifier.isHidden = false
            SeConnecter.isHidden = false
            SeConnecterAAutre.isHidden = false
//TEMP            safari.isHidden = true
            
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
        AppDelegate.shared.getToken()

//        if let token = AppDelegate.shared.getToken() {
//            goToProfile(token: token)
//        }
    }
    
    @IBAction func connectOther(_ sender: Any) {
        safari.isHidden = false
        AppDelegate.shared.removeToken {
            print("last was removed")
        }
    }
    
    @IBAction func connectWithSafari(_ sender: Any) {
        AppDelegate.shared.setToken(AuthToken(idToken: nil, accessToken: "", refreshToken: nil, tokenType: nil, expiresIn: nil, user: nil))
    }
}

