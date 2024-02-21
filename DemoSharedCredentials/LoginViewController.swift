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
//        let shared = SecureStorage(group: Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String + "com.reach5.SharedItems")
//        let localToken: String? = AppDelegate.local.get(key: "token")
//        let sharedToken: String? = shared.get(key: "token")
        
        let tk: AuthToken = AuthToken(idToken: "toto", accessToken: "toto", refreshToken: "toto", tokenType: "toto", expiresIn: 100000, user: nil)
//        AppDelegate.local.save(key: "token", value: tk)
        if let token: AuthToken = AppDelegate.local.get(key: "token") {
            print("did find token on LoginViewController.viewWillAppear")
            guard let profileController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Profile") as? ProfileViewController else {
                print("did not find ProfileViewController")
                return
            }
            
            print("initialized profileController")
            profileController.authToken = token
            navigationController?.pushViewController(profileController, animated: true)
        } else {
            print("token not found on LoginViewController.viewWillAppear")
            Identifier.isHidden = true
            SeConnecter.isHidden = true
            SeConnecterAAutre.isHidden = true
            safari.isHidden = false
        }
    }

    @IBAction func connectWithToken(_ sender: Any) {
    }
    
    @IBAction func connectOther(_ sender: Any) {
        safari.isHidden = false
    }
    
    @IBAction func connectWithSafari(_ sender: Any) {
    }
}

