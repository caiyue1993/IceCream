//
//  AppDelegate.swift
//  IceCream
//
//  Created by 278060043@qq.com on 10/17/2017.
//  Copyright (c) 2017 278060043@qq.com. All rights reserved.
//

import UIKit
import IceCream
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var syncEngine: SyncEngine<Dog>?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        syncEngine = SyncEngine<Dog>()
        application.registerForRemoteNotifications()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ViewController())
        window?.makeKeyAndVisible()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let dict = userInfo as! [String: NSObject]
        let notification = CKNotification(fromRemoteNotificationDictionary: dict)
        
        if (notification.subscriptionID == Constants.cloudSubscriptionID) {
             NotificationCenter.default.post(name: .databaseDidChangeRemotely, object: nil, userInfo: userInfo)
        }
        completionHandler(.newData)
        
    }
    
}

