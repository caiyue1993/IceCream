//
//  Object+CKRecord.swift
//  IceCream
//
//  Created by 蔡越 on 11/11/2017.
//

import Foundation
import CloudKit
import RealmSwift

public protocol CKRecordConvertible {
    static var recordType: String { get }
    static var customZoneID: CKRecordZoneID { get }
    
    var recordID: CKRecordID { get }
    var record: CKRecord { get }
    
    var isDeleted: Bool { get }
}

struct CloudKitToObject {
    
    static func create<O: Object>(object: O.Type, withRecord record: CKRecord) -> O? {
        let o = O()
        for prop in o.objectSchema.properties {
            var recordValue: Any?
            switch prop.type {
            case .int:
                recordValue = record.value(forKey: prop.name) as? Int
            case .string:
                recordValue = record.value(forKey: prop.name) as? String
            case .bool:
                recordValue = record.value(forKey: prop.name) as? Bool
            case .date:
                recordValue = record.value(forKey: prop.name) as? Date
            case .float:
                recordValue = record.value(forKey: prop.name) as? Float
            case .double:
                recordValue = record.value(forKey: prop.name) as? Double
            case .data:
                recordValue = record.value(forKey: prop.name) as? Data
            case .object:
                guard let asset = record.value(forKey: prop.name) as? CKAsset else {
                    print("For now, the Object only support CKAsset related type.")
                    break
                }
                recordValue = CreamAsset.parse(from: prop.name, record: record, asset: asset)
            default:
                print("Other types will be supported in the future.")
            }
            o.setValue(recordValue, forKey: prop.name)
        }
        
        return o
    }
}

extension CKRecordConvertible where Self: Object {
    
    public static var recordType: String {
        return className()
    }
    
    public static var customZoneID: CKRecordZoneID {
        return CKRecordZoneID(zoneName: "IceCream", ownerName: CKCurrentUserDefaultName)
    }
    
    /// recordName : this is the unique identifier for the record, used to locate records on the database. We can create our own ID or leave it to CloudKit to generate a random UUID.
    /// For more: https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda
    public var recordID: CKRecordID {
        guard let sharedSchema = Self.sharedSchema() else {
            fatalError("No schema settled. Go to Realm Community to seek more help.")
        }
        
        guard let primaryKeyProperty = sharedSchema.primaryKeyProperty else {
            fatalError("You should set a primary key on your Realm object")
        }
        
        let zoneID: CKRecordZoneID
        if self is StoredInPublicDatabase {
            zoneID = CKRecordZone.default().zoneID
        } else {
            zoneID = Self.customZoneID
        }
        
        if let primaryValueString = self[primaryKeyProperty.name] as? String {
            return CKRecordID(recordName: primaryValueString, zoneID: zoneID)
        } else if let primaryValueInt = self[primaryKeyProperty.name] as? Int {
            return CKRecordID(recordName: "\(primaryValueInt)", zoneID: zoneID)
        } else {
            fatalError("Primary key should be String or Int")
        }
    }
    
    // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
    public var record: CKRecord {
        let r = CKRecord(recordType: Self.recordType, recordID: recordID)
        let properties = objectSchema.properties
        for prop in properties {
            switch prop.type {
            case .int, .string, .bool, .date, .float, .double, .data:
                r[prop.name] = self[prop.name] as? CKRecordValue
            case .object:
                guard let objectName = prop.objectClassName else { break }
                if objectName == CreamAsset.className() {
                    if let creamAsset = self[prop.name] as? CreamAsset {
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

public protocol StoredInPublicDatabase {
}
