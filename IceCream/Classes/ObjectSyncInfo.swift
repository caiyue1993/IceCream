//
//  ObjectSyncInfo.swift
//  IceCream
//
//  Created by Andrew Eades on 09/03/2018.
//

import Foundation
import RealmSwift
import CloudKit
import Realm

class ObjectSyncInfo {
    
    let objectType: Object.Type
    
    /// Dangerous part:
    /// In most cases, you should not change the string value cause it is related to user settings.
    /// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
    /// Or your user will not save the same subscription again. So you got trouble.
    /// The right way is remove old subscription first and then save new subscription.
    let cloudKitSubscriptionID: String
  
    private var databaseZone: DatabaseZone

    var notificationToken: NotificationToken? = nil

    var name: String {
        return objectType.className()
    }
    
    var T: Object.Type {
        return objectType.self
    }
    
    private var database: CKDatabase {
        return databaseZone.database
    }
    
    var recordZoneID: CKRecordZoneID {
        return databaseZone.recordZone.zoneID
    }
    
    private var sharedSchema: RLMObjectSchema? {
        return T.sharedSchema()
    }
    
    func recordID(of object: Object & CKRecordConvertible) -> CKRecordID {
        guard let sharedSchema = sharedSchema else {
            fatalError("No schema settled. Go to Realm Community to seek more help.")
        }
        
        guard let primaryKeyProperty = sharedSchema.primaryKeyProperty else {
            fatalError("You should set a primary key on your Realm object")
        }
        
        //        guard let zoneID: CKRecordZoneID = ObjectSyncEngine.zoneID(forRecordType: Self.recordType) else {
        //            fatalError("\(Self.recordType) has not been registered for syncing.")
        //        }
        
        //        if self is StoredInPublicDatabase {
        //            zoneID = CKRecordZone.default().zoneID
        //        } else {
        //            zoneID = NewSyncEngine.customZoneID
        //        }
        
        if let primaryValueString = object[primaryKeyProperty.name] as? String {
            return CKRecordID(recordName: primaryValueString, zoneID: recordZoneID)
        } else if let primaryValueInt = object[primaryKeyProperty.name] as? Int {
            return CKRecordID(recordName: "\(primaryValueInt)", zoneID: recordZoneID)
        } else {
            fatalError("Primary key should be String or Int")
        }
    }
    
    // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
    func cloudKitRecord(from object: Object & CKRecordConvertible) -> CKRecord {
        let recordID = self.recordID(of: object)
        let objectSchema = sharedSchema!
        
        let r = CKRecord(recordType: name, recordID: recordID)
        let properties = objectSchema.properties
        for prop in properties {
            switch prop.type {
            case .int, .string, .bool, .date, .float, .double, .data:
                r[prop.name] = object[prop.name] as? CKRecordValue
            case .object:
                guard let objectName = prop.objectClassName else { break }
                if objectName == CreamAsset.className() {
                    if let creamAsset = object[prop.name] as? CreamAsset {
                        r[prop.name] = creamAsset.asset
                    } else {
                        /// Just a warm hint:
                        /// When we set nil to the property of a CKRecord, that record's property will be hidden in the CloudKit Dashboard
                        r[prop.name] = nil
                    }
                }
            default:
                break
            }
            
        }
        return r
    }
    
    
    func createDatabaseSubscription(errorHandler: ErrorHandler) {
        
        let recordType = name
        let subscription = CKQuerySubscription(recordType: recordType,
                                               predicate: NSPredicate(value: true),
                                               subscriptionID: cloudKitSubscriptionID,
                                               options: [.firesOnRecordCreation,
                                                         .firesOnRecordUpdate,
                                                         .firesOnRecordDeletion])
        
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        notificationInfo.alertBody = nil //"BOO"
        
        subscription.notificationInfo = notificationInfo
        
        SubscriptionManager.shared.renew(subscription: subscription, for: database) { errors in
            print(errors ?? "")
        }
    }

    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    func syncRecordsToCloudKit(errorHandler: ErrorHandler, recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
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
            (_, _, error) in
            
            switch errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    self.createDatabaseSubscription(errorHandler: errorHandler)
                }
            case .retry(let timeToWait, _):
                errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    self.syncRecordsToCloudKit(errorHandler: errorHandler, recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be a fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    self.syncRecordsToCloudKit(errorHandler: errorHandler, recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        
        database.add(modifyOpe)
    }

    /// When you commit a write transaction to a Realm, all other instances of that Realm will be notified, and be updated automatically.
    /// For more: https://realm.io/docs/swift/latest/#writes
    
    func registerLocalDatabase(errorHandler: ErrorHandler) {
        Realm.query { realm in
            let objects = realm.objects(self.T)
             self.notificationToken = objects.observe({ (changes) in
                
                switch changes {
                case .initial(let collection):
                    print("Inited:" + "\(collection)")
                    break
                case .update(let collection, let deletions, let insertions, let modifications):
                    print("collections:" + "\(collection)")
                    print("deletions:" + "\(deletions)")
                    print("insertions:" + "\(insertions)")
                    print("modifications:" + "\(modifications)")
                    
                    let objectsToStore = (insertions + modifications)
                        .filter { $0 < collection.count }
                        .map { i -> (Object & CKRecordConvertible)? in return collection[i] as? Object & CKRecordConvertible }
                        .filter { $0 != nil }.map { $0! }
                        .filter{ !$0.isDeleted }
                    
                    let objectsToDelete = modifications
                        .filter { $0 < collection.count }
                        .map { i -> (Object & CKRecordConvertible)? in return collection[i] as? Object & CKRecordConvertible }
                        .filter { $0 != nil }.map { $0! }
                        .filter { $0.isDeleted }
                    
                    self.syncObjectsToCloudKit(errorHandler: errorHandler, objectsToStore: objectsToStore, objectsToDelete: objectsToDelete)
                    
                case .error(_):
                    break
                }
                
            })
        }
    }
    
    // This method is commonly used when you want to push your datas to CloudKit manually
    // In most cases, you don't need this
    private func syncObjectsToCloudKit(errorHandler: ErrorHandler, objectsToStore: [Object & CKRecordConvertible], objectsToDelete: [Object & CKRecordConvertible] = []) {
        guard objectsToStore.count > 0 || objectsToDelete.count > 0 else { return }
        
        let recordsToStore = objectsToStore.map{ self.cloudKitRecord(from: $0) }
        let recordIDsToDelete = objectsToDelete.map{ self.recordID(of: $0) }
        
        syncRecordsToCloudKit(errorHandler: errorHandler, recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete) { error in
            guard error == nil else { return }
            guard !objectsToDelete.isEmpty else { return }
            
            let realm = try! Realm()
            try! realm.write {
                realm.delete(objectsToDelete as [Object])
            }
            
            print("Completeed deletion of \(objectsToDelete.count) objects")
        }
    }
    

    init(objectType: Object.Type, cloudKitSubscriptionID: String, databaseZone: DatabaseZone) {
        self.objectType = objectType
        self.cloudKitSubscriptionID = cloudKitSubscriptionID
        self.databaseZone = databaseZone

        let name = objectType.className()
        ObjectTypeRegister.entries[name] = objectType
    }
}
