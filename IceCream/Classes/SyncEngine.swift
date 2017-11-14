//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

public extension Notification.Name {
    public static let databaseDidChangeRemotely = Notification.Name(rawValue: "databaseDidChangeRemotely")
}

public struct Constants {
    
    static let databaseChangesTokenKey = "database_changes_token"
    static let zoneChangesTokenKey = "zone_changes_token"
    static let subscriptionIsLocallyCachedKey = "subscription_is_locally_cached"
    static let customZoneName = "DogsZone"
    static let isVeryFirstLaunchKey = "is_very_first_launch"
    
    public static let cloudSubscriptionID = "private_changes"
    public static let customZoneID = CKRecordZoneID(zoneName: Constants.customZoneName, ownerName: CKCurrentUserDefaultName)
    
}

public final class SyncEngine<T: Object & CKRecordConvertible & CKRecordRecoverable> {
    
    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?
    
//    fileprivate var changedRecordZoneID: CKRecordZoneID?
    
    /// Indicates the private database in default container
    let privateDatabase = CKContainer.default().privateCloudDatabase
    
    let realm = try! Realm()
    
    /// We recommand process the initialization when app launches
    public init() {
        /// Check iCloud status so that we can go on
        CKContainer.default().accountStatus { [weak self](status, error) in
            guard let `self` = self else { return }
            if status == CKAccountStatus.available {
                
                /// 1. Fetch changes in the Cloud
                if (`self`.isVeryFirstLaunch) {
                    `self`.fetchChangesInDatabase({
                        print("First sync done!")
                        `self`.isVeryFirstLaunch = false
                    })
                }
                
                `self`.createCustomZone()
                
                `self`.beginObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    `self`.registerLocalDatabase()
                }
                
                /// 3. Subscribe to future changes
                if (`self`.subscriptionIsLocallyCached) { return }
                `self`.createDatabaseSubscription()
                
            } else {
                /// Handle when user account is not available
            }
        }
    }
    
    /// When you commit a write transaction to a Realm, all other instances of that Realm will be notified, and be updated automatically.
    /// For more: https://realm.io/docs/swift/latest/#writes

    private func registerLocalDatabase() {
        let objects = Cream().realm.objects(T.self)
        notificationToken = objects.observe({ [weak self](changes) in
            guard let `self` = self else { return }
            
            switch changes {
            case .initial(let collection):
                print("Inited:" + "\(collection)")
                break
            case .update(let collection, let deletions, let insertions, let modifications):
                print("collections:" + "\(collection)")
                print("deletions:" + "\(deletions)")
                print("insertions:" + "\(insertions)")
                print("modifications:" + "\(modifications)")
                
                let objectsToStore = (insertions + modifications).map { collection[$0] }
                let objectsToDelete = deletions.map { collection[$0] }
                
                `self`.syncObjectsToCloudKit(objectsToStore: objectsToStore, objectsToDelete: objectsToDelete)
                
            case .error(_):
                break
            }
        })
    }
    
    private func syncObjectsToCloudKit(objectsToStore: [T], objectsToDelete: [T]) {
        guard objectsToStore.count > 0 || objectsToDelete.count > 0 else { return }
        
        let recordsToStore = objectsToStore.map{ $0.record }
        let recordIDsToDelete = objectsToDelete.map{ $0.recordID }
        
        syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
    }
    
}

/// Chat to the CloudKit API directly
extension SyncEngine {
    
    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    var databaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: Constants.databaseChangesTokenKey) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.setNilValueForKey(Constants.databaseChangesTokenKey)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: Constants.databaseChangesTokenKey)
        }
    }
    
    var zoneChangesToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: Constants.zoneChangesTokenKey) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.setNilValueForKey(Constants.zoneChangesTokenKey)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: Constants.zoneChangesTokenKey)
        }
    }
    
    /// Cuz we only need to do subscription once succeed
    var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: Constants.subscriptionIsLocallyCachedKey) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.subscriptionIsLocallyCachedKey)
        }
    }
    
    var isVeryFirstLaunch: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: Constants.isVeryFirstLaunchKey) as? Bool else { return true }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.isVeryFirstLaunchKey)
        }
    }
    
    /// Only update the changeToken when fetch process completes
    private func fetchChangesInDatabase(_ callback: (() -> Void)? = nil) {
        
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true
        
        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
            guard let `self` = self else { return }
            self.databaseChangeToken = newToken
        }
        
        /// Cuz we only have one custom zone, so we don't need to store the CKRecordZoneID temporarily
        /*
        changesOperation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
            guard let `self` = self else { return }
            `self`.changedRecordZoneID = zoneID
        }
        */
        changesOperation.fetchDatabaseChangesCompletionBlock = { [weak self] newToken, _, error in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.fetchChangesInDatabase(callback)
                })
                return
            }
            self?.databaseChangeToken = newToken
            // Fetch the changes in zone level
            self?.fetchChangesInZone(callback)
        }
        privateDatabase.add(changesOperation)
    }
    
    private func fetchChangesInZone(_ callback: (() -> Void)? = nil) {
        
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangesToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [Constants.customZoneID], optionsByRecordZoneID: [Constants.customZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.zoneChangesToken = token
        }
        changesOp.recordChangedBlock = { [weak self]record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let `self` = self else { return }
            guard let object = T.objectFrom(record: record) else {
                print("There is something wrong with the converson from cloud record to local object")
                return
            }
            DispatchQueue.main.async {
                /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
                /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
                `self`.realm.beginWrite()
                `self`.realm.add(object, update: true)
                if let token = `self`.notificationToken {
                    try! `self`.realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! `self`.realm.commitWrite()
                }
            }
        }
        changesOp.recordWithIDWasDeletedBlock = { [weak self]recordId, _ in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                guard let object = `self`.realm.object(ofType: T.self, forPrimaryKey: recordId.recordName) else {
                    // Not found in local
                    return
                }
                `self`.realm.beginWrite()
                `self`.realm.delete(object)
                if let token = `self`.notificationToken {
                    try! `self`.realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! `self`.realm.commitWrite()
                }
            }
        }
        changesOp.recordZoneFetchCompletionBlock = { [weak self](_,token, _, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.fetchChangesInZone(callback)
                })
                return
            }
            self?.zoneChangesToken = token
            print("Sync successfully!")
        }
        privateDatabase.add(changesOp)
    }
 
    
    /// Create new custom zones
    /// You can(but you shouldn't) invoke this method more times, but the CloudKit is smart and will handle that for you
    fileprivate func createCustomZone(_ completion: ((Error?) -> ())? = nil) {
        let newCustomZone = CKRecordZone(zoneID: Constants.customZoneID)
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: [newCustomZone], recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.createCustomZone(completion)
                })
                return
            }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOp)
    }
 
    /// Check if custom zone already exists
   /* fileprivate func checkCustomZoneExists(_ completion: ((Error?) -> ())? = nil) {
        let checkZoneOp = CKFetchRecordZonesOperation(recordZoneIDs: [customZoneID])
        checkZoneOp.fetchRecordZonesCompletionBlock = { dic, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(checkZoneOp)
    }
 */
    
    fileprivate func createDatabaseSubscription() {
        // The direct below is the subscribe way that Apple suggests in CloudKit Best Practices(https://developer.apple.com/videos/play/wwdc2016/231/) , but it doesn't work here in my place.
        /*
        let subscription = CKDatabaseSubscription(subscriptionID: Constants.cloudSubscriptionID)

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
        let subscription = CKQuerySubscription(recordType: T.recordType, predicate: NSPredicate(value: true), subscriptionID: Constants.cloudSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { [weak self](_, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.createDatabaseSubscription()
                })
                return
            }
            print("Register remote successfully!")
            self?.subscriptionIsLocallyCached = true
            return
        }
    }
    
    fileprivate func beginObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: .databaseDidChangeRemotely, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let `self` = self else { return }
            `self`.fetchChangesInDatabase()
        })
    }
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    fileprivate func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        modifyOpe.savePolicy = .allKeys
        modifyOpe.modifyRecordsCompletionBlock = { [weak self](_, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                })
                return
            }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOpe)
    }
}

/// Error Handling
extension SyncEngine {
    fileprivate func retryOperationIfPossible(with error: Error?, block: @escaping () -> ()) {
        guard let e = error as? CKError else {
            print("WTF is the CloudKit? Dial 911 to seek more help")
            return
        }
        switch e.code {
        case .internalError, .serverRejectedRequest, .invalidArguments, .permissionFailure:
            print("These errors are unrecoverable and should not be retried")
        case .zoneBusy, .serviceUnavailable, .requestRateLimited:
            if let retryAfter = e.userInfo[CKErrorRetryAfterKey] as? Double {
                let delayTime = DispatchTime.now() + retryAfter
                DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
                    block()
                })
            }
        default:
            print("Error: " + e.localizedDescription)
        }
    }
}
