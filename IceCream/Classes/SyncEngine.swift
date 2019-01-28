//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

/// SyncEngine talks to CloudKit directly.
/// Logically,
/// 1. it takes care of the operations of **CKDatabase**
/// 2. it handles all of the CloudKit config stuffs, such as subscriptions
/// 3. it hands over CKRecordZone stuffs to SyncObject so that it can have an effect on local Realm Database

public final class SyncEngine {
    
    /// Indicates the private database in default container
    private let defaultContainer : CKContainer
    private let privateDatabase : CKDatabase
    
    private let errorHandler = ErrorHandler()
    private let syncObjects: [Syncable]
    
    /// We recommend processing the initialization when app launches
    public init(objects: [Syncable], container: CKContainer = CKContainer.default(), in realm: Realm = try! Realm()) {
        defaultContainer = container
        privateDatabase = container.privateCloudDatabase
        
        self.syncObjects = objects
        for syncObject in syncObjects {
            syncObject.realm = realm
            syncObject.pipeToEngine = { [weak self] recordsToStore, recordIDsToDelete in
                guard let self = self else { return }
                self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
            }
        }
        
        /// Check iCloud status so that we can go on
        defaultContainer.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            if status == CKAccountStatus.available {
                
                /// 1. Fetch changes in the Cloud
                /// Apple suggests that we should fetch changes in database, *especially* the very first launch.
                /// But actually, there **might** be some rare unknown and weird reason that the data is not synced between muilty devices.
                /// So I suggests fetch changes in database everytime app launches.
                self.fetchChangesInDatabase()

                self.resumeLongLivedOperationIfPossible()

                self.createCustomZones { [weak self] (error) in
                    guard let self = self, error == nil else { return }
                    /// 2. Register to local database
                    /// We should call `registerLocalDatabase` after custom zones were created, related issue: https://github.com/caiyue1993/IceCream/issues/83
                    for syncObject in self.syncObjects {
                        syncObject.registerLocalDatabase()
                    }
                }
                
                self.startObservingRemoteChanges()
              
                #if os(iOS) || os(tvOS)
              
                NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: UIApplication.willTerminateNotification, object: nil)
                
                #elseif os(macOS)
                
                NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: NSApplication.willTerminateNotification, object: nil)
                
                #endif
                
                /// 3. Create the subscription to the CloudKit database
                if self.subscriptionIsLocallyCached { return }
                self.createDatabaseSubscription()

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
            guard let self = self else { return }
            switch self.errorHandler.resultType(with: error) {
            case .success:
                self.syncObjects.forEach { $0.isCustomZoneCreated = true }
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.createCustomZones(completion)
                })
            default:
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }

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

    /// Only update the changeToken when fetch process completes
    private func fetchChangesInDatabase(_ callback: (() -> Void)? = nil) {

        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true

        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
            guard let self = self else { return }
            self.databaseChangeToken = newToken
        }

        /// Cuz we only have one custom zone, so we don't need to store the CKRecordZoneID temporarily
        /*
         changesOperation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
         guard let self = self else { return }
         self.changedRecordZoneID = zoneID
         }
         */
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            [weak self]
            newToken, _, error in
            guard let self = self else { return }
            switch self.errorHandler.resultType(with: error) {
            case .success:
                self.databaseChangeToken = newToken
                // Fetch the changes in zone level
                self.fetchChangesInZones(callback)
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInDatabase(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    self.databaseChangeToken = nil
                    self.fetchChangesInDatabase(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        privateDatabase.add(changesOperation)
    }

    private var zoneIds: [CKRecordZone.ID] {
        return syncObjects.map { $0.customZoneID }
    }

    private var zoneIdOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] {
        return syncObjects.reduce([CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()) { (dict, syncEngine) -> [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] in
            var dict = dict
            let zoneChangesOptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
            zoneChangesOptions.previousServerChangeToken = syncEngine.zoneChangesToken
            dict[syncEngine.customZoneID] = zoneChangesOptions
            return dict
        }
    }

    private func fetchChangesInZones(_ callback: (() -> Void)? = nil) {
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: zoneIdOptions)
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneId, token, _ in
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
            syncObject.zoneChangesToken = token
        }

        changesOp.recordChangedBlock = { [weak self] record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.recordType == record.recordType }) else { return }
            syncObject.add(record: record)
        }

        changesOp.recordWithIDWasDeletedBlock = { [weak self] recordId, _ in
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.customZoneID == recordId.zoneID }) else { return }
            syncObject.delete(recordID: recordId)
        }

        changesOp.recordZoneFetchCompletionBlock = { [weak self](zoneId ,token, _, _, error) in
            guard let self = self else { return }
            switch self.errorHandler.resultType(with: error) {
            case .success:
                guard let syncObject = self.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
                syncObject.zoneChangesToken = token
                callback?()
                print("Sync successfully: \(zoneId))")
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInZones(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    guard let syncObject = self.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
                    syncObject.zoneChangesToken = nil
                    self.fetchChangesInZones(callback)
                default:
                    return
                }
            default:
                return
            }
        }

        privateDatabase.add(changesOp)
    }

    fileprivate func createDatabaseSubscription() {
        #if os(iOS) || os(tvOS) || os(macOS)
        
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
        privateDatabase.add(createOp)
        
        #endif
    }

    fileprivate func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: nil, using: { [weak self](_) in
            guard let self = self else { return }
            DispatchQueue.global(qos: .utility).async {
                self.fetchChangesInDatabase()
            }
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
        defaultContainer.fetchAllLongLivedOperationIDs { [weak self]( opeIDs, error) in
            guard let self = self else { return }
            guard error == nil else { return }
            guard let ids = opeIDs else { return }
            for id in ids {
                self.defaultContainer.fetchLongLivedOperation(withID: id, completionHandler: { [weak self](ope, error) in
                    guard let self = self else { return }
                    guard error == nil else { return }
                    if let modifyOp = ope as? CKModifyRecordsOperation {
                        modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
                            print("Resume modify records success!")
                        }
                        self.defaultContainer.add(modifyOp)
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
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
      
        if #available(iOS 11.0, OSX 10.13, tvOS 11.0, watchOS 4.0, *) {
            let config = CKOperation.Configuration()
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
        
        modifyOpe.modifyRecordsCompletionBlock = {
            [weak self]
            (_, _, error) in
            
            guard let self = self else { return }
            
            switch self.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    if self.subscriptionIsLocallyCached { return }
                    self.createDatabaseSubscription()
                }
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    self.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        
        privateDatabase.add(modifyOpe)
    }
    
    /// Fetch data on the CloudKit and merge with local
    public func pull() {
        fetchChangesInDatabase()
    }
    
    /// Push all existing local data to CloudKit
    /// You should NOT to call this method too frequently
    public func pushAll() {
        self.syncObjects.forEach { $0.pushLocalObjectsToCloudKit() }
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

