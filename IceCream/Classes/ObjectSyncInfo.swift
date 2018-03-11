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

public struct ObjectSyncInfo {
    let objectType: Object.Type
    let subscriptionIsLocallyCachedKey: String
    
    /// Dangerous part:
    /// In most cases, you should not change the string value cause it is related to user settings.
    /// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
    /// Or your user will not save the same subscription again. So you got trouble.
    /// The right way is remove old subscription first and then save new subscription.
    let cloudKitSubscriptionID: String
  
    private var databaseZone: DatabaseZone

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
    
    // Cuz we only need to do subscription once succeed
    private var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: subscriptionIsLocallyCachedKey) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: subscriptionIsLocallyCachedKey)
        }
    }
    
    public mutating func createDatabaseSubscription(errorHandler: ErrorHandler) {
        
        if subscriptionIsLocallyCached { return }
        
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
        
        let recordType = name
        /// So I use the @Guilherme Rambo's plan: https://github.com/insidegui/NoteTaker
        let subscription = CKQuerySubscription(recordType: recordType, predicate: NSPredicate(value: true), subscriptionID: cloudKitSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        subscription.notificationInfo = notificationInfo
        
        var myself = self
        database.save(subscription) { (_, error) in
            switch errorHandler.resultType(with: error) {
            case .success:
                print("Register remote successfully!")
                myself.subscriptionIsLocallyCached = true
            case .retry(let timeToWait, _):
                errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    myself.createDatabaseSubscription(errorHandler: errorHandler)
                })
            default:
                return
            }
        }
    }

    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    mutating func syncRecordsToCloudKit(errorHandler: ErrorHandler, recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
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
            
            
            switch errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    if myself.subscriptionIsLocallyCached { return }
                    myself.createDatabaseSubscription(errorHandler: errorHandler)
                }
            case .retry(let timeToWait, _):
                errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    myself.syncRecordsToCloudKit(errorHandler: errorHandler, recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be a fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    myself.syncRecordsToCloudKit(errorHandler: errorHandler, recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        
        database.add(modifyOpe)
    }

    init(objectType: Object.Type, subscriptionIsLocallyCachedKey: String, cloudKitSubscriptionID: String, databaseZone: DatabaseZone) {
        self.objectType = objectType
        self.subscriptionIsLocallyCachedKey = subscriptionIsLocallyCachedKey
        self.cloudKitSubscriptionID = cloudKitSubscriptionID
        self.databaseZone = databaseZone

        let name = objectType.className()
        ObjectTypeRegister.entries[name] = objectType
    }
}
