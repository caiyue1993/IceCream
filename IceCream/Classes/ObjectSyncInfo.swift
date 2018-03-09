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

struct ObjectSyncInfo {
    let objectType: Object.Type
    let subscriptionIsLocallyCachedKey: String
    let recordZone: CKRecordZone
    let database: CKDatabase
    
    /// Dangerous part:
    /// In most cases, you should not change the string value cause it is related to user settings.
    /// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
    /// Or your user will not save the same subscription again. So you got trouble.
    /// The right way is remove old subscription first and then save new subscription.
    let cloudKitSubscriptionID: String
    
    var name: String {
        return objectType.className()
    }
    
    var T: Object.Type {
        return objectType.self
    }
    
    var recordZoneID: CKRecordZoneID {
        return recordZone.zoneID
    }
    
    var sharedSchema: RLMObjectSchema? {
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
}

