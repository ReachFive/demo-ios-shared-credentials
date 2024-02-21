//
//  ViewController.swift
//  DemoSharedCredentials
//
//  Created by François Devémy on 19/02/2024.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet var Identifier: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let local = SecureStorage()
        let shared = SecureStorage(group: Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String + "com.reach5.SharedItems")
        let localToken: String? = local.get(key: "token")
        let sharedToken: String? = shared.get(key: "token")
        
        

    }

    @IBAction func connectWithToken(_ sender: Any) {
    }
    
    @IBAction func connectOther(_ sender: Any) {
    }
    
    @IBAction func connectWithSafari(_ sender: Any) {
    }
}

