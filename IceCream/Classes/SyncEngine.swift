//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

public enum IceCreamKey: String {
    /// Tokens
    case databaseChangesTokenKey
    case zoneChangesTokenKey
    
    /// Flags
    case subscriptionIsLocallyCachedKey
    case hasCustomZoneCreatedKey
    
    public var value: String {
        return "icecream.keys." + rawValue
    }
}

/// Dangerous part:
/// In most cases, you should not change the string value cause it is related to user settings.
/// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
/// Or your user will not save the same subscription again. So you got trouble.
/// The right way is remove old subscription first and then save new subscription.
public struct IceCreamConstant {
    public static let cloudKitSubscriptionID = "private_changes"
}

public final class SyncEngine<T: Object & CKRecordConvertible & CKRecordRecoverable> {
    
    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?
    
//    fileprivate var changedRecordZoneID: CKRecordZoneID?
    
    /// Indicates the private database in default container
    let privateDatabase = CKContainer.default().privateCloudDatabase
    
    private lazy var errorHandler = ErrorHandler()
    
    /// We recommand process the initialization when app launches
    public init() {
        /// Check iCloud status so that we can go on
        CKContainer.default().accountStatus { [weak self] (status, error) in
            guard let `self` = self else { return }
            if status == CKAccountStatus.available {
                
                /// 1. Fetch changes in the Cloud
                /// Apple suggests that we should fetch changes in database, *especially* the very first launch.
                /// But actually, there **might** be some rare unknown and weird reason that the data is not synced between muilty devices.
                /// So I suggests fetch changes in database everytime app launches.
                `self`.fetchChangesInDatabase({
                    print("First sync done!")
                })
                
                `self`.resumeLongLivedOperationIfPossible()
                
                if (!`self`.isCustomZoneCreated) {
                    `self`.createCustomZone()
                }
                
                `self`.startObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    `self`.registerLocalDatabase()
                }
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: .UIApplicationWillTerminate, object: nil)
                
            } else {
                /// Handle when user account is not available
                print("Easy, my boy. You haven't logged into iCloud account on your device/simulator yet.")
            }
        }
    }
    
    /// When you commit a write transaction to a Realm, all other instances of that Realm will be notified, and be updated automatically.
    /// For more: https://realm.io/docs/swift/latest/#writes

    private func registerLocalDatabase() {
        let objects = Cream<T>().realm.objects(T.self)
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
                
                let objectsToStore = (insertions + modifications).filter { $0 < collection.count }.map { collection[$0] }.filter{ !$0.isDeleted }
                let objectsToDelete = modifications.filter { $0 < collection.count }.map{ collection[$0] }.filter { $0.isDeleted }
                
                `self`.syncObjectsToCloudKit(objectsToStore: objectsToStore, objectsToDelete: objectsToDelete)
                
            case .error(_):
                break
            }
        })
    }
    
    @objc func cleanUp() {
        let cream = Cream<T>()
        do {
            try cream.deletePreviousSoftDeleteObjects(notNotifying: notificationToken)
        } catch {
            // Error handles here
        }
    }
}

/// Public Methods
extension SyncEngine {
    
    // Manually sync data with CloudKit
    public func sync() {
        self.fetchChangesInDatabase()
    }
    
    // This method is commonly used when you want to push your datas to CloudKit manually
    // In most cases, you don't need this
    public func syncObjectsToCloudKit(objectsToStore: [T], objectsToDelete: [T] = []) {
        guard objectsToStore.count > 0 || objectsToDelete.count > 0 else { return }
        
        let recordsToStore = objectsToStore.map{ $0.record }
        let recordIDsToDelete = objectsToDelete.map{ $0.recordID }
        
        self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
    }

}

/// Chat to the CloudKit API directly
extension SyncEngine {
    
    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    var databaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.databaseChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.databaseChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.databaseChangesTokenKey.value)
        }
    }
    
    var zoneChangesToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.zoneChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.zoneChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.zoneChangesTokenKey.value)
        }
    }
    
    /// Cuz we only need to do subscription once succeed
    var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value)
        }
    }
    
    /*
    var isVeryFirstLaunch: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: IceCreamConstants.isVeryFirstLaunchKey) as? Bool else { return true }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: IceCreamConstants.isVeryFirstLaunchKey)
        }
    }
    */
    
    var isCustomZoneCreated: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: IceCreamKey.hasCustomZoneCreatedKey.value) as? Bool else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: IceCreamKey.hasCustomZoneCreatedKey.value)
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
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            [weak self]
            newToken, _, error in
            switch self?.errorHandler.handleCKErrorAs(error) {
            case .success?:
                self?.databaseChangeToken = newToken
                // Fetch the changes in zone level
                self?.fetchChangesInZone(callback)
            case .retry(let timeToWait, _)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self?.fetchChangesInDatabase(callback)
                })
            case .recoverableError(let reason, _)?:
                switch reason {
                case .changeTokenExpired:
                    self?.zoneChangesToken = nil
                    self?.databaseChangeToken = nil
                default:
                    return
                }
            default: // any other reason
                return
            }
        }
        privateDatabase.add(changesOperation)
    }
    
    private func fetchChangesInZone(_ callback: (() -> Void)? = nil) {
        
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangesToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [T.customZoneID], optionsByRecordZoneID: [T.customZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.zoneChangesToken = token
        }
        
        changesOp.recordChangedBlock = { [weak self]record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let `self` = self else { return }
            guard let object = T().parseFromRecord(record: record)  else {
                print("There is something wrong with the converson from cloud record to local object")
                return
            }

            DispatchQueue.main.async {
                let realm = try! Realm()

                /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
                /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
                realm.beginWrite()
                realm.add(object, update: true)
                if let token = `self`.notificationToken {
                    try! realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! realm.commitWrite()
                }
            }
        }
        
        changesOp.recordWithIDWasDeletedBlock = { [weak self]recordId, _ in
            guard let `self` = self else { return }
            
            DispatchQueue.main.async {
                let realm = try! Realm()
                guard let object = realm.object(ofType: T.self, forPrimaryKey: recordId.recordName) else {
                    // Not found in local
                    return
                }
                realm.beginWrite()
                realm.delete(object)
                if let token = `self`.notificationToken {
                    try! realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! realm.commitWrite()
                }
            }
        }
        
        changesOp.recordZoneFetchCompletionBlock = { [weak self](_,token, _, _, error) in
            switch self?.errorHandler.handleCKErrorAs(error) {
            case .success?:
                self?.zoneChangesToken = token
                callback?()
                print("Sync successfully!")
            case .retry(let timeToWait, _)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self?.fetchChangesInZone(callback)
                })
            default: // any other reason
                return
            }
        }
        
        privateDatabase.add(changesOp)
    }
 
    
    /// Create new custom zones
    /// You can(but you shouldn't) invoke this method more times, but the CloudKit is smart and will handle that for you
    fileprivate func createCustomZone(_ completion: ((Error?) -> ())? = nil) {
        let newCustomZone = CKRecordZone(zoneID: T.customZoneID)
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: [newCustomZone], recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            switch self?.errorHandler.handleCKErrorAs(error) {
            case .success?:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                     self?.createCustomZone(completion)
                })
            default: // any other reason
                return
            }
        }
        
        privateDatabase.add(modifyOp)
    }
 
    /// Check if custom zone already exists
  /* fileprivate func checkCustomZoneExists(_ completion: ((Error?) -> ())? = nil) {
        let checkZoneOp = CKFetchRecordZonesOperation(recordZoneIDs: [customZoneID])
        checkZoneOp.fetchRecordZonesCompletionBlock = { dic, error in
            switch self?.errorHandler.handleCKErrorAs(error) {
            case .success?:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self?.checkCustomZoneExists(completion)
                })
            default: // any other reason
                return
            }
        }
        privateDatabase.add(checkZoneOp)
    }
*/
    
    fileprivate func createDatabaseSubscription() {
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
        let subscription = CKQuerySubscription(recordType: T.recordType, predicate: NSPredicate(value: true), subscriptionID: IceCreamConstant.cloudKitSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { [weak self](_, error) in
            switch self?.errorHandler.handleCKErrorAs(error) {
            case .success?:
                print("Register remote successfully!")
                self?.subscriptionIsLocallyCached = true
            case .retry(let timeToWait, _)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self?.createDatabaseSubscription()
                })
            default: // any other reason
                return
            }
        }
    }
    
    fileprivate func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let `self` = self else { return }
            `self`.fetchChangesInDatabase()
        })
    }
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    fileprivate func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
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
        
        // to avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
        // If you want to handle partial failures, set .isAtomic to false and implement CKErrorTYpe .fail(reason: .partialFailure) where appropriate
        modifyOpe.isAtomic = true
        
        modifyOpe.modifyRecordsCompletionBlock = {
            [weak self]
            (_, _, error) in
            switch self?.errorHandler.handleCKErrorAs(error) {
            case .success?:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    if let cached = self?.subscriptionIsLocallyCached {
                        if cached { return }
                        self?.createDatabaseSubscription()
                    }
                }
            case .retry(let timeToWait, _)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    self?.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk?:
                let recordChunks = recordsToStore.chunk(by: 2)
                for chunk in recordChunks {
                    self?.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default: // any other reason
                return
            }
        }
        
        privateDatabase.add(modifyOpe)
    }
}

/// Long-lived Manipulation
extension SyncEngine {
    /// The CloudKit Best Practice is out of date, now use this:
    /// https://developer.apple.com/documentation/cloudkit/ckoperation
    /// Which problem does this func solve? E.g.:
    /// 1.(Offline) You make a local change, involve a operation
    /// 2. App exits or ejected by user
    /// 3. Back to app again
    /// The operation resumes! All works like a magic!
    fileprivate func resumeLongLivedOperationIfPossible () {
        CKContainer.default().fetchAllLongLivedOperationIDs { ( opeIDs, error) in
            guard error == nil else { return }
            guard let ids = opeIDs else { return }
            for id in ids {
                CKContainer.default().fetchLongLivedOperation(withID: id, completionHandler: { (ope, error) in
                    guard error == nil else { return }
                    if let modifyOp = ope as? CKModifyRecordsOperation {
                        modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
                            print("Resume modify records success!")
                        }
                        CKContainer.default().add(modifyOp)
                    }
                })
            }
        }
    }
}
