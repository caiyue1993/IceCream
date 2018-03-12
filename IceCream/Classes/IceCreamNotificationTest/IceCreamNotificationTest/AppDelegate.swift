//
//  AppDelegate.swift
//  IceCreamNotificationTest
//
//  Created by Andrew Eades on 11/03/2018.
//  Copyright © 2018 Andrew Eades. All rights reserved.
//

import UIKit
import UserNotifications
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { authorized, error in
            if authorized {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        })

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

extension AppDelegate {
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Error: \(error)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Success: didRegisterForRemoteNotificationsWithDeviceToken")
        
//        let subscription = CKQuerySubscription(recordType: "Dog", predicate: NSPredicate(format: "TRUEPREDICATE"), options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate])
//
//        let info = CKNotificationInfo()
////        info.alertBody = "A new notification has been posted!"
////        info.shouldBadge = true
////        info.soundName = "default"
//        info.shouldSendContentAvailable = true
//        subscription.notificationInfo = info
//
//        let database = CKContainer(identifier: "iCloud.com.intrepidfrog.IceCreamExample2").privateCloudDatabase
//        database.save(subscription, completionHandler: { subscription, error in
//            if error == nil {
//                // Subscription saved successfully
//                print("yes")
//            } else {
//                // An error occurred
//                print("\(error)")
//            }
//        })
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
            completionHandler([.alert, .sound])
        }
}
