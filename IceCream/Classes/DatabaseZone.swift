//
//  DatabaseZone.swift
//  IceCream
//
//  Created by Andrew Eades on 10/03/2018.
//

import Foundation
import CloudKit
import RealmSwift

protocol NotificationTokenStore {
    var notificationTokens: [NotificationToken] { get }
}

class DatabaseZone: Hashable {
    let database: CKDatabase
    let recordZone: CKRecordZone
    
    var notificationTokenStore: NotificationTokenStore? = nil
    
    var hashValue: Int {
        let id = "\(database.databaseScope.string):\(recordZone.zoneID.zoneName)"

        return id.hashValue
    }
    
    static func ==(lhs: DatabaseZone, rhs: DatabaseZone) -> Bool {
        return lhs.database == rhs.database && lhs.recordZone == rhs.recordZone
    }
    
    var recordZoneID: CKRecordZoneID {
        return recordZone.zoneID
    }

    private let databaseChangesTokenKey: String
    private let zoneChangesTokenKey: String

    init(database: CKDatabase, recordZone: CKRecordZone, multiObjectSupport: Bool = true) {
        self.database = database
        self.recordZone = recordZone
        
        if !multiObjectSupport {
            databaseChangesTokenKey = "icecream.keys.databaseChangesTokenKey"
            zoneChangesTokenKey = "icecream.keys.zoneChangesTokenKey"
        } else {
            let databaseScope = database.databaseScope.string
            
            let zoneName = recordZone.zoneID.zoneName
            
            databaseChangesTokenKey = "icecream.keys.databaseChangesTokenKey.\(databaseScope)"
            zoneChangesTokenKey = "icecream.keys.zoneChangesTokenKey.\(databaseScope).\(zoneName)"
        }
    }
    
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
    func fetchChangesInDatabase(_ callback: (() -> Void)? = nil) {
        
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true
        
        changesOperation.changeTokenUpdatedBlock = { newToken in
            self.databaseChangeToken = newToken
        }
        
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            newToken, _, error in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                self.databaseChangeToken = newToken
                // Fetch the changes in zone level
                self.fetchChangesInZone(callback)
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
        
        database.add(changesOperation)
    }
    
    private func fetchChangesInZone(_ callback: (() -> Void)? = nil) {
        
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangesToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZoneID], optionsByRecordZoneID: [recordZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.zoneChangesToken = token
        }
        
        changesOp.recordChangedBlock = { record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let objectType = ObjectTypeRegister.entries[record] else { fatalError() }
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
                try! realm.commitWrite(withoutNotifying: self.notificationTokenStore?.notificationTokens ?? [])
            }
        }
        
        changesOp.recordWithIDWasDeletedBlock = { recordID, _ in

                guard let objectType = ObjectTypeRegister.entries[recordID] else { return }

                DispatchQueue.main.async {
                    let realm = try! Realm()
                        
                    guard let object = realm.object(ofType: objectType, forPrimaryKey: recordID.recordName) else {
                        // Not found in local
                        return
                    }
                    
                    CreamAsset.deleteCreamAssetFile(with: recordID.recordName)
                    realm.beginWrite()
                    realm.delete(object)
                    try! realm.commitWrite(withoutNotifying: self.notificationTokenStore?.notificationTokens ?? [])
                }
        }
        
        changesOp.recordZoneFetchCompletionBlock = { (_,token, _, _, error) in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                self.zoneChangesToken = token
                callback?()
                print("Sync successfully!")
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInZone(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    self.zoneChangesToken = nil
                    self.fetchChangesInZone(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        database.add(changesOp)
    }
    
    /// Create new custom zones
    /// You can(but you shouldn't) invoke this method more times, but the CloudKit is smart and will handle that for you
    func createCustomZone(_ completion: ((Error?) -> ())? = nil) {
        let newCustomZone = CKRecordZone(zoneID: self.recordZoneID)
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: [newCustomZone], recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { (_, _, error) in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.createCustomZone(completion)
                })
            default:
                return
            }
        }
        
        database.add(modifyOp)
    }

}
