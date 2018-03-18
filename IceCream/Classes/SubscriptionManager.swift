//
//  SubscriptionManager.swift
//  IceCream
//
//  Created by Andrew Eades on 12/03/2018.
//

import Foundation
import CloudKit

class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    func fetchSubscriptions(for database: CKDatabase, completionHandler onCompletion: @escaping ([CKSubscription]?, Error?) -> Void) {
        database.fetchAllSubscriptions { subscriptions, error in
            guard error == nil else {
                onCompletion(nil, error)
                return
            }
            
            guard let subscriptions = subscriptions else {
                onCompletion(nil, error)
                return
            }
            
            onCompletion(subscriptions, error)
        }
    }

    func renew(subscription renewingSubscription: CKSubscription, for database: CKDatabase, completionHandler onCompletion: @escaping ([Error]?) -> Void) {
        renew(subscriptions: [renewingSubscription], for: database, completionHandler: onCompletion)
    }
    
    func renew(subscriptions renewingSubscriptions: [CKSubscription], for database: CKDatabase, completionHandler onCompletion: @escaping ([Error]?) -> Void) {
        
        var errors: [Error] = []
        fetchSubscriptions(for: database) { subscriptions, error in
            guard error == nil else {
                onCompletion([error!])
                return
            }
            guard let subscriptions = subscriptions else {
                onCompletion([error!])
                return
            }
            
            var waitingForCallback = renewingSubscriptions.count
            func checkCompletion() {
                
                waitingForCallback -= 1
                if waitingForCallback == 0 {
                    if errors.isEmpty {
                        onCompletion(nil)
                    } else {
                        onCompletion(errors)
                    }
                }
            }
            
            func save(subscription: CKSubscription) {
                database.save(subscription) { subscription, error in
                    if error != nil {
                        errors.append(error!)
                    }
                    
                    checkCompletion()
                }
            }
            
            renewingSubscriptions.forEach { subscription in
                let subscriptionID = subscription.subscriptionID
                
                if !subscriptions.contains(where: {subscription in return subscription.subscriptionID == subscriptionID}) {
                    
                    save(subscription: subscription)
                }
            }
        }
     }
}
