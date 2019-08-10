//
//  AppDelegate.swift
//  IceCream_Example-macOS
//
//  Created by caiyue on 2019/8/7.
//  Copyright © 2019 蔡越. All rights reserved.
//

import Cocoa
import IceCream
import CloudKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var syncEngine: SyncEngine?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        syncEngine = SyncEngine(objects: [SyncObject<Dog>()], container: CKContainer(identifier: "iCloud.me.soledad.http.IceCream-Example"))
        NSApp.registerForRemoteNotifications()
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo), let subscriptionID = notification.subscriptionID, IceCreamSubscription.allIDs.contains(subscriptionID) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
        }
    }


}

