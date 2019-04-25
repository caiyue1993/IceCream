//
//  AppDelegate.swift
//  IceCream
//
//  Created by 蔡越 on 10/17/2017.
//  Copyright (c) 2017 Nanjing University. All rights reserved.
//

import UIKit
import IceCream
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var syncEngine: SyncEngine?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        syncEngine = SyncEngine(objects: [
            SyncObject<Person>(),
            SyncObject<Dog>(),
            SyncObject<Cat>()
            ])
      
        // If you wanna test public Database, comment the above syncEngine code and try the following one
//        syncEngine = SyncEngine(objects: [SyncObject<Person>()], databaseScope: .public)
        
        application.registerForRemoteNotifications()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = TabBarViewController()
        window?.makeKeyAndVisible()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let dict = userInfo as! [String: NSObject]
        let notification = CKNotification(fromRemoteNotificationDictionary: dict)
        
        if let subscriptionID = notification.subscriptionID, IceCreamSubscription.allIDs.contains(subscriptionID) {
             NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
        }
        completionHandler(.newData)
        
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        
        // How about fetching changes here?
        
    }
}

