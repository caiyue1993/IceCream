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
    
    private let errorHandler = ErrorHandler()
    
    private let syncObjects: [Syncable]

    private let remoteDataSource: CloudKitDataSourcing

    /// We recommend starting when app launches
    public static func start(objects: [Syncable]) -> SyncEngine {
        let cloudKitDataSource = CloudKitDataSource(zoneIds: objects.map { $0.customZoneID }, zoneIdOptions: {
            return SyncEngine.zoneIdOptions(from: objects)
        }, zonesToCreate: {
            return objects.filter { !$0.isCustomZoneCreated }.map { CKRecordZone(zoneID: $0.customZoneID) }
        })
        return SyncEngine(remoteDataSource: cloudKitDataSource, objects: objects)
    }

    public static func start(objects: [Syncable], remoteDataSource: CloudKitDataSourcing) -> SyncEngine {
        return SyncEngine(remoteDataSource: remoteDataSource, objects: objects)
    }

    private init(remoteDataSource: CloudKitDataSourcing, objects: [Syncable]) {
        self.syncObjects = objects
        self.remoteDataSource = remoteDataSource
        pipeSyncObjectsChangesToRemote()
        setupCloudKit()
    }

    private func pipeSyncObjectsChangesToRemote() {
        for syncObject in syncObjects {
            syncObject.pipeToEngine = { [weak self] recordsToStore, recordIDsToDelete in
                guard let `self` = self else { return }
                `self`.remoteDataSource.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: nil)
            }
        }
    }

    private func setupCloudKit() {
        remoteDataSource.cloudKitAvailable { [weak self]  available in
            guard let `self` = self else { return }
            guard available else {
                /// Handle when user account is not available
                print("Easy, my boy. You haven't logged into iCloud account on your device/simulator yet.")
                return
            }
            `self`.fetchChangesInDatabase()
            /// Register to local database
            DispatchQueue.main.async {
                for syncObject in `self`.syncObjects {
                    syncObject.registerLocalDatabase()
                }
            }
            NotificationCenter.default.addObserver(self, selector: #selector(`self`.cleanUp), name: .UIApplicationWillTerminate, object: nil)
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
}

// MARK: Public Method
extension SyncEngine {
    // Manually sync data with CloudKit
    public func sync() {
        fetchChangesInDatabase()
    }
}

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

/// Dangerous part:
/// In most cases, you should not change the string value cause it is related to user settings.
/// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
/// Or your user will not save the same subscription again. So you got trouble.
/// The right way is remove old subscription first and then save new subscription.
public struct IceCreamConstant {
    public static let cloudKitSubscriptionID = "private_changes"
}

