//
//  DatabaseZone.swift
//  IceCream
//
//  Created by Andrew Eades on 10/03/2018.
//

import Foundation
import CloudKit
import RealmSwift

struct DatabaseZone: Hashable {
    let database: CKDatabase
    let recordZone: CKRecordZone
    
    var hashValue: Int {
        return database.hashValue ^ recordZone.hashValue
    }
    
    static func ==(lhs: DatabaseZone, rhs: DatabaseZone) -> Bool {
        return lhs.database == rhs.database && lhs.recordZone == rhs.recordZone
    }
    
    var recordZoneID: CKRecordZoneID {
        return recordZone.zoneID
    }
    
    private let databaseChangesTokenKey = "icecream.keys.databaseChangesTokenKey"
    private let zoneChangesTokenKey = "icecream.keys.zoneChangesTokenKey"
    private let subscriptionIsLocallyCachedKey = "icecream.keys.subscriptionIsLocallyCachedKey"
    
    let cloudKitSubscriptionID = "private_changes"

    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    var databaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: databaseChangesTokenKey) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: databaseChangesTokenKey)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: databaseChangesTokenKey)
        }
    }
    
    var zoneChangesToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: zoneChangesTokenKey) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: zoneChangesTokenKey)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: zoneChangesTokenKey)
        }
    }
    
    private let errorHandler = ErrorHandler()
    
    /// Only update the changeToken when fetch process completes
    mutating func fetchChangesInDatabase(notificationToken: NotificationToken?, _ callback: (() -> Void)? = nil) {
        
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true
        
        var myself = self
        changesOperation.changeTokenUpdatedBlock = { newToken in
            myself.databaseChangeToken = newToken
        }
        
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            newToken, _, error in
            switch myself.errorHandler.resultType(with: error) {
            case .success:
                myself.databaseChangeToken = newToken
                // Fetch the changes in zone level
                myself.fetchChangesInZone(notificationToken: notificationToken, callback)
            case .retry(let timeToWait, _):
                myself.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    myself.fetchChangesInDatabase(notificationToken: notificationToken, callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    myself.databaseChangeToken = nil
                    myself.fetchChangesInDatabase(notificationToken: notificationToken, callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        database.add(changesOperation)
    }
    
    private mutating func fetchChangesInZone(notificationToken: NotificationToken?, _ callback: (() -> Void)? = nil) {
        
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangesToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZoneID], optionsByRecordZoneID: [recordZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        var myself = self
        changesOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            myself.zoneChangesToken = token
        }
        
        changesOp.recordChangedBlock = { record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let objectType = ObjectSyncInfo.objectTypeFor(record: record) else { fatalError() }
            guard let object = CloudKitToObject.object(ofType: objectType, withRecord: record) else {
                print("There is something wrong with the conversion from cloud record to local object")
                return
            }
            
            DispatchQueue.main.async {
                let realm = try! Realm()
                
                /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
                /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
                realm.beginWrite()
                realm.add(object, update: true)
                if let token = notificationToken {
                    try! realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! realm.commitWrite()
                }
            }
        }
        
        changesOp.recordWithIDWasDeletedBlock = { recordID, _ in

                guard let objectType = ObjectSyncInfo.objectTypeFrom(recordID: recordID) else { return }

                DispatchQueue.main.async {
                    let realm = try! Realm()
                        
                    guard let object = realm.object(ofType: objectType, forPrimaryKey: recordID.recordName) else {
                        // Not found in local
                        return
                    }
                    
                    CreamAsset.deleteCreamAssetFile(with: recordID.recordName)
                    realm.beginWrite()
                    realm.delete(object)
                    if let token = notificationToken {
                        try! realm.commitWrite(withoutNotifying: [token])
                    } else {
                        try! realm.commitWrite()
                    }
                }
        }
        
        changesOp.recordZoneFetchCompletionBlock = { (_,token, _, _, error) in
            switch myself.errorHandler.resultType(with: error) {
            case .success:
                myself.zoneChangesToken = token
                callback?()
                print("Sync successfully!")
            case .retry(let timeToWait, _):
                myself.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    myself.fetchChangesInZone(notificationToken: notificationToken, callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    myself.zoneChangesToken = nil
                    myself.fetchChangesInZone(notificationToken: notificationToken, callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        database.add(changesOp)
    }
    
    public mutating func createDatabaseSubscription(forType recordType: String) {
        // The direct below is the subscribe way that Apple suggests in CloudKit Best Practices(https://developer.apple.com/videos/play/wwdc2016/231/) , but it doesn't work here in my place.
        /*
         let subscription = CKDatabaseSubscription(subscriptionID: IceCreamConstants.cloudSubscriptionID)
         
         let notificationInfo = CKNotificationInfo()
         notificationInfo.shouldSendContentAvailable = true // Silent Push
         
         subscription.notificationInfo = notificationInfo
         
         let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
         createOp.modifySubscriptionsCompletionBlock = { _, _, error in
         guard error == nil else { return }
         self.subscriptionIsLocallyCached = true
         }
         createOp.qualityOfService = .utility
         privateDatabase.add(createOp)
         */
        
        /// So I use the @Guilherme Rambo's plan: https://github.com/insidegui/NoteTaker
        let subscription = CKQuerySubscription(recordType: recordType, predicate: NSPredicate(value: true), subscriptionID: cloudKitSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        subscription.notificationInfo = notificationInfo
        
        var myself = self
        database.save(subscription) { (_, error) in
            switch myself.errorHandler.resultType(with: error) {
            case .success:
                print("Register remote successfully!")
                myself.subscriptionIsLocallyCached = true
            case .retry(let timeToWait, _):
                myself.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    myself.createDatabaseSubscription(forType: recordType)
                })
            default:
                return
            }
        }
    }
    
    // Cuz we only need to do subscription once succeed
    var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: subscriptionIsLocallyCachedKey) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: subscriptionIsLocallyCachedKey)
        }
    }
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    mutating func syncRecordsToCloudKit(objectSyncInfo: ObjectSyncInfo, recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        
        if #available(iOS 11.0, *) {
            let config = CKOperationConfiguration()
            config.isLongLived = true
            modifyOpe.configuration = config
        } else {
            // Fallback on earlier versions
            modifyOpe.isLongLived = true
        }
        
        // We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
        // Apple suggests using .ifServerRecordUnchanged save policy
        // For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
        modifyOpe.savePolicy = .changedKeys
        
        // To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
        // If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
        modifyOpe.isAtomic = true
        
        var myself = self

        modifyOpe.modifyRecordsCompletionBlock = {
            (_, _, error) in
            

            switch myself.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    if myself.subscriptionIsLocallyCached { return }
                    myself.createDatabaseSubscription(forType: objectSyncInfo.name)
                }
            case .retry(let timeToWait, _):
                myself.errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    myself.syncRecordsToCloudKit(objectSyncInfo: objectSyncInfo, recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be a fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    myself.syncRecordsToCloudKit(objectSyncInfo: objectSyncInfo, recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        
        database.add(modifyOpe)
    }

}
