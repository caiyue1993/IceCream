//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

/// SyncEngine talks to CloudKit directly.
/// Logically,
/// 1. it takes care of the operations of CKDatabase
/// 2. it handles all of the CloudKit config stuffs, such as subscriptions
/// 3. it hands over CKRecordZone stuffs to SyncObject so that it can have an effect on local Realm Database

public final class SyncEngine {

    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?

    /// Indicates the private database in default container
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    
    private let errorHandler = ErrorHandler()
    
    private let syncObjects: [Syncable]

    private let remoteDataSource: RemoteDataSourcing

    /// We recommend starting when app launches
    public static func start(objects: [Syncable]) -> SyncEngine {
        let cloudKitDataSource = CloudKitRemoteDataSource(zoneIds: objects.map { $0.customZoneID }, zoneIdOptions: {
            return SyncEngine.zoneIdOptions(from: objects)
        })
        return SyncEngine(remoteDataSource: cloudKitDataSource, objects: objects)
    }

    private init(remoteDataSource: RemoteDataSourcing, objects: [Syncable]) {
        self.syncObjects = objects
        self.remoteDataSource = remoteDataSource
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
                `self`.fetchChangesInDatabase()

                `self`.remoteDataSource.resumeLongLivedOperationIfPossible()

                let zonesToCreate = `self`.syncObjects.filter { !$0.isCustomZoneCreated }.map { CKRecordZone(zoneID: $0.customZoneID) }
                `self`.remoteDataSource.createCustomZones(zonesToCreate: zonesToCreate, nil)
                
                `self`.startObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    for syncObject in `self`.syncObjects {
                        syncObject.registerLocalDatabase()
                    }
                }
                
                NotificationCenter.default.addObserver(self, selector: #selector(`self`.cleanUp), name: .UIApplicationWillTerminate, object: nil)
                
                /// 3. Create the subscription to the CloudKit database
                if `self`.subscriptionIsLocallyCached { return }
                `self`.createDatabaseSubscription()

            } else {
                /// Handle when user account is not available
                print("Easy, my boy. You haven't logged into iCloud account on your device/simulator yet.")
            }
        }
    }

    @objc func cleanUp() {
        for syncObject in syncObjects {
            syncObject.cleanUp()
        }
    }
}

/// Chat to the CloudKit API directly
extension SyncEngine {
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
    private func fetchChangesInDatabase() {
        let updateToken: (CKRecordZoneID, CKServerChangeToken?) -> Void = { [weak self] zoneId, changeToken in
            guard let `self` = self else { return }
            guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == zoneId }) else { return }
            syncObject.zoneChangesToken = changeToken
        }

        let added: (CKRecord) -> Void = { [weak self] record in
            guard let `self` = self else { return }
            guard let syncObject = `self`.syncObjects.first(where: { $0.recordType == record.recordType }) else { return }
            syncObject.add(record: record)
        }

        let deleted: (CKRecordID) -> Void = {[weak self] recordId in
            guard let `self` = self else { return }
            guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == recordId.zoneID }) else { return }
            syncObject.delete(recordID: recordId)
        }
        remoteDataSource.fetchChanges(recordZoneTokenUpdated: updateToken, added: added, removed: deleted)
    }

    private static func zoneIdOptions(from objects: [Syncable]) -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions] {
        return objects.reduce([CKRecordZoneID: CKFetchRecordZoneChangesOptions]()) { (dict, syncEngine) -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions] in
            var dict = dict
            let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
            zoneChangesOptions.previousServerChangeToken = syncEngine.zoneChangesToken
            dict[syncEngine.customZoneID] = zoneChangesOptions
            return dict
        }
    }

    fileprivate func createDatabaseSubscription() {
        // The direct below is the subscribe way that Apple suggests in CloudKit Best Practices(https://developer.apple.com/videos/play/wwdc2016/231/) , but it doesn't work here in my place.

        let subscription = CKDatabaseSubscription(subscriptionID: IceCreamConstant.cloudKitSubscriptionID)

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
    }

    fileprivate func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let `self` = self else { return }
            `self`.fetchChangesInDatabase()
        })
    }
}

// MARK: Public Method
extension SyncEngine {
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    public func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
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
        
        modifyOpe.modifyRecordsCompletionBlock = {
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
        
        privateDatabase.add(modifyOpe)
    }
    
    // Manually sync data with CloudKit
    public func sync() {
        fetchChangesInDatabase()
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

