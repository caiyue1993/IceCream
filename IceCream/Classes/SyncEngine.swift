//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

struct Constants {
   // static let databaseChangesToken = "DatabaseChangesToken"
    static let databaseChangesTokenKey = "database_changes_token"
    
    static let customZoneName = "custom_zone_name"
}

public final class SyncEngine<T: Object & CKRecordConvertible> {
    
    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?
    
    /// Indicates the private database in default container
    let privateDatabase = CKContainer.default().privateCloudDatabase
    
    
    let customZoneID = CKRecordZoneID(zoneName: Constants.customZoneName, ownerName: CKCurrentUserDefaultName)
    
    /// We recommand process the initialization when app launches
    public init() {
        /// Check iCloud status so that we can go on
        CKContainer.default().accountStatus { [weak self](status, error) in
            guard let `self` = self else { return }
            if status == CKAccountStatus.available {
                
                /// 1. Fetch changes in the Cloud
//                `self`.fetchChangesInZone {
//                    print("Fetch changes successfully!")
//                }
                
                
                /// 2. Subscribe to future changes
                
                
                
                /// 3. Register to local database
                DispatchQueue.main.async {
                    `self`.registerLocalDatabase()
                }
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
    /*
    var databaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: Constants.databaseChangesToken) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.setNilValueForKey(Constants.databaseChangesToken)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: Constants.databaseChangesToken)
        }
    }
    */
    
    var databaseChangesToken: CKServerChangeToken? {
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
    
    /// Only update the changeToken when fetch process completes
    private func fetchChangesInDatabase(_ callback: () -> Void) {
        
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangesToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true
        
        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
            guard let `self` = self else { return }
            self.databaseChangesToken = newToken
        }
        
        changesOperation.fetchDatabaseChangesCompletionBlock = { [weak self] newToken, _, error in
            guard error == nil else {
                // Handle when error occurs
                return
            }
            self?.databaseChangesToken = newToken
            
            // Fetch zone changes, need to add
            
        }
        privateDatabase.add(changesOperation)
    }
 
    
    
    /*
    private func fetchChangesInZone(_ callback: () -> Void) {
        
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangesToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZoneID], optionsByRecordZoneID: [customZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.zoneChangesToken = token
        }
        changesOp.recordChangedBlock = { record in
            print(record)
        }
        changesOp.recordWithIDWasDeletedBlock = { recordId, _ in
            
        }
        changesOp.recordZoneFetchCompletionBlock = { _,token, _, _, error in
            guard error == nil else { return }
            self.zoneChangesToken = token
        }
        privateDatabase.add(changesOp)
    }
    */
    
    /// Create new custom zones
    /*
    fileprivate func createCustomZone(_ completion: ((Error?) -> ())? = nil) {
        let newCustomZone = CKRecordZone(zoneID: customZoneID)
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: [newCustomZone], recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { _, _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOp)
    }
 */
    
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
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    fileprivate func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        modifyOpe.savePolicy = .allKeys
        modifyOpe.modifyRecordsCompletionBlock = { _, _, error in
            guard error == nil else {
                // Handle when error occurs
                return
            }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOpe)
    }
    
    
}
