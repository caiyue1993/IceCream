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
    case publicDatabaseChangesTokenKey
    case privateDatabaseChangesTokenKey
    case sharedDatabaseChangesTokenKey
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

/// SyncEngine talks to CloudKit directly.
/// Logically,
/// 1. it takes care of the operations of CKDatabase
/// 2. it handles all of the CloudKit config stuffs, such as subscriptions
/// 3. it hands over CKRecordZone stuffs to SyncObject so that it can have an effect on local Realm Database

public final class SyncEngine {
    
    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?

    private let errorHandler = ErrorHandler()
    
    private let syncObjects: [Syncable]
    
    /// We recommend processing the initialization when app launches
    public init(objects: [Syncable]) {
        self.syncObjects = objects
        for syncObject in syncObjects {
            syncObject.pipeToEngine = { [weak self] recordsToStore, recordIDsToDelete in
                guard let `self` = self else { return }
                `self`.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
            }
        }
        
        /// Check iCloud status so that we can go on
        CKContainer.default().accountStatus { [weak self] (status, error) in
            guard let `self` = self else { return }
            if status == CKAccountStatus.available {
                
                /// 1. Fetch changes in the Cloud
                /// Apple suggests that we should fetch changes in database, *especially* the very first launch.
                /// But actually, there **might** be some rare unknown and weird reason that the data is not synced between muilty devices.
                /// So I suggests fetch changes in database everytime app launches.
                `self`.fetchChangesInDatabase(databaseType: .dbPrivate, {
                    print("First private sync done!")
                })
                `self`.fetchChangesInDatabase(databaseType: .dbShared,{
                    print("First shared sync done!")
                })

                `self`.resumeLongLivedOperationIfPossible()

                `self`.createCustomZones()
                
                `self`.startObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    for syncObject in `self`.syncObjects {
                        syncObject.registerLocalDatabase()
                    }
                }
                
                NotificationCenter.default.addObserver(self, selector: #selector(`self`.cleanUp), name: UIApplication.willTerminateNotification, object: nil)
                
                /// 3. Create the subscription to the CloudKit database
                if `self`.subscriptionIsLocallyCached { return }
                `self`.createDatabaseSubscription()

            } else {
                /// Handle when user account is not available
                print("Easy, my boy. You haven't logged into iCloud account on your device/simulator yet.")
            }
        }
    }

    /// Create new custom zones
    /// You can(but you shouldn't) invoke this method more times, but the CloudKit is smart and will handle that for you
    private func createCustomZones(_ completion: ((Error?) -> ())? = nil) {
        let zonesToCreate = syncObjects.filter { !$0.isCustomZoneCreated }.map { CKRecordZone(zoneID: $0.customZoneID) }
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: zonesToCreate, recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    `self`.createCustomZones(completion)
                })
            default:
                return
            }
        }
        // We only want to create the custom zone in the private database
        let privateDatabase = DatabaseType.dbPrivate.dataBase()
        privateDatabase.add(modifyOp)
    }

    @objc func cleanUp() {
        for syncObject in syncObjects {
            syncObject.cleanUp()
        }
    }
}

/// Chat to the CloudKit API directly
extension SyncEngine {

    var privateDatabaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.privateDatabaseChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.privateDatabaseChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.privateDatabaseChangesTokenKey.value)
        }
    }
    var sharedDatabaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.sharedDatabaseChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.sharedDatabaseChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.sharedDatabaseChangesTokenKey.value)
        }
    }

    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    var publicDatabaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.publicDatabaseChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.publicDatabaseChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.publicDatabaseChangesTokenKey.value)
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

    private func update(token: CKServerChangeToken?, for databaseType: DatabaseType) {
        switch databaseType {
        case .dbPrivate:
            self.privateDatabaseChangeToken = token
        case .dbShared:
            self.sharedDatabaseChangeToken = token
        }
    }
    
    /// Only update the changeToken when fetch process completes
    private func fetchChangesInDatabase(databaseType: DatabaseType, _ callback: (() -> Void)? = nil) {
        var zoneIDsChanged = [CKRecordZone.ID]()
        // TODO handle deleted zones
        var zoneIDsDeleted = [CKRecordZone.ID]()

        var databaseChangeToken: CKServerChangeToken?
        switch databaseType {
        case .dbPrivate:
            databaseChangeToken = privateDatabaseChangeToken
        case .dbShared:
            databaseChangeToken = sharedDatabaseChangeToken
        }
        let changesOp = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOp.fetchAllChanges = true

        changesOp.changeTokenUpdatedBlock = { [weak self] newToken in
            guard let `self` = self else { return }
                `self`.update(token: newToken, for: databaseType)
        }

        changesOp.recordZoneWithIDChangedBlock = { [weak self] zoneID in
            guard let _ = self else { return }
            zoneIDsChanged.append(zoneID)
        }
 
        changesOp.fetchDatabaseChangesCompletionBlock = {
            [weak self]
            newToken, _, error in
            guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                `self`.update(token: newToken, for: databaseType)
                // Fetch the changes in zone level
                `self`.fetchChangesInZones(databaseType: databaseType, zoneIDs: zoneIDsChanged, callback)
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    `self`.fetchChangesInZones(databaseType: databaseType, zoneIDs: zoneIDsChanged, callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    `self`.update(token: nil, for: databaseType)
                    `self`.fetchChangesInDatabase(databaseType: databaseType, callback)
                default:
                    return
                }
            default:
                return
            }
        }
        databaseType.dataBase().add(changesOp)
    }

    @available(iOS 12.0, *)
    private var zoneIdOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] {
        return syncObjects.reduce([CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()) { (dict, syncEngine) -> [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] in
            var dict = dict
            let zoneChangesConfiguration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            zoneChangesConfiguration.previousServerChangeToken = syncEngine.zoneChangesToken
            dict[syncEngine.customZoneID] = zoneChangesConfiguration
            return dict
        }
    }
    
    private var legacyZoneIdOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] {
        return syncObjects.reduce([CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()) { (dict, syncEngine) -> [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] in
            var dict = dict
            let zoneChangesOptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
            zoneChangesOptions.previousServerChangeToken = syncEngine.zoneChangesToken
            dict[syncEngine.customZoneID] = zoneChangesOptions
            return dict
        }
    }

    private func fetchChangesInZones(databaseType: DatabaseType, zoneIDs: [CKRecordZone.ID], _ callback: (() -> Void)? = nil) {
        var changesOp: CKFetchRecordZoneChangesOperation
        if #available(iOS 12.0, *) {
            changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, configurationsByRecordZoneID: zoneIdOptions)
        } else {
            // Fallback on earlier versions
            changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: legacyZoneIdOptions)
        }
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneId, token, _ in
            guard let `self` = self else { return }
            guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
            syncObject.zoneChangesToken = token
        }

        changesOp.recordChangedBlock = { [weak self] record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let `self` = self else { return }
            guard let syncObject = `self`.syncObjects.first(where: { $0.recordType == record.recordType }) else { return }
            syncObject.add(databaseType: databaseType, record: record)
        }

        changesOp.recordWithIDWasDeletedBlock = { [weak self] recordId, _ in
            guard let `self` = self else { return }
            guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == recordId.zoneID }) else { return }
            syncObject.delete(recordID: recordId)
        }

        changesOp.recordZoneFetchCompletionBlock = { [weak self](zoneId , token, clientChangeTokenData, isMoreComing, error) in
            guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
                syncObject.zoneChangesToken = token
                callback?()
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    `self`.fetchChangesInZones(databaseType: databaseType, zoneIDs: zoneIDs, callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
                    syncObject.zoneChangesToken = nil
                    `self`.fetchChangesInZones(databaseType: databaseType, zoneIDs: zoneIDs, callback)
                default:
                    return
                }
            default:
                return
            }
        }
        databaseType.dataBase().add(changesOp)
    }

    fileprivate func createDatabaseSubscription() {
        // The direct below is the subscribe way that Apple suggests in CloudKit Best Practices(https://developer.apple.com/videos/play/wwdc2016/231/) , but it doesn't work here in my place.

        for database in [DatabaseType.dbPrivate.dataBase(), DatabaseType.dbShared.dataBase()] {
            let subscription = CKDatabaseSubscription(subscriptionID: IceCreamConstant.cloudKitSubscriptionID)
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true // Silent Push
            
            subscription.notificationInfo = notificationInfo
            
            let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
            createOp.modifySubscriptionsCompletionBlock = { _, _, error in
                guard error == nil else { return }
                self.subscriptionIsLocallyCached = true
            }
            createOp.qualityOfService = .utility
            database.add(createOp)
        }
    }

    fileprivate func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let `self` = self else { return }
            `self`.fetchChangesInDatabase(databaseType: .dbPrivate)
            `self`.fetchChangesInDatabase(databaseType: .dbShared)
        })
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

// MARK: Public Method
extension SyncEngine {
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    public func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: ((Error?) -> ())? = nil) {
        let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        
        if #available(iOS 11.0, *) {
            let config = CKOperation.Configuration()
            config.isLongLived = true
            modifyOp.configuration = config
        } else {
            // Fallback on earlier versions
            modifyOp.isLongLived = true
        }
        
        // We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
        // Apple suggests using .ifServerRecordUnchanged save policy
        // For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
        modifyOp.savePolicy = .changedKeys
        
        // To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
        // If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
        modifyOp.isAtomic = true
        
        modifyOp.modifyRecordsCompletionBlock = {
            [weak self]
            (_, _, error) in
            
            guard let `self` = self else { return }
            
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    if `self`.subscriptionIsLocallyCached { return }
                    `self`.createDatabaseSubscription()
                }
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    `self`.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be a fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    `self`.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        DatabaseType.dbPrivate.dataBase().add(modifyOp)
    }
    
    // Manually sync data with CloudKit
    public func sync() {
        fetchChangesInDatabase(databaseType: .dbPrivate)
        fetchChangesInDatabase(databaseType: .dbShared)
    }
}

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

