//
//  AppDelegate.swift
//  DemoSharedCredentials
//
//  Created by François Devémy on 19/02/2024.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
/*
        let local = SecureStorage()
        let shared = SecureStorage(group: Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String + "com.reach5.SharedItems")
        local.save(key: "key", value: "local")
        local.save(key: "local", value: "local")
        shared.save(key: "key", value: "shared")
        shared.save(key: "shared", value: "shared")
        print(local.get(key: "key") as String?)
        print(local.get(key: "local") as String?)
        print(local.get(key: "shared") as String?)
        print(local.get(key: "external") as String?)
        print(shared.get(key: "key") as String?)
        print(shared.get(key: "local") as String?)
        print(shared.get(key: "shared") as String?)
        print(shared.get(key: "external") as String?)
*/
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

