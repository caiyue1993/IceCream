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

public protocol CKRecordRecoverable {
    
}

extension CKRecordRecoverable where Self: Object {
    func parseFromRecord(record: CKRecord) -> Object? {
        let o = Object()
        let props = o.objectSchema.properties
        var recordValue: Any?
        for prop in props {
            switch prop.type {
            case .int:
                recordValue = record.value(forKey: prop.name) as! Int
            case .string:
                recordValue = record.value(forKey: prop.name) as! String
            case .bool:
                recordValue = record.value(forKey: prop.name) as! Bool
            default:
                recordValue = record.value(forKey: prop.name) as! Bool
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
        return CKRecordZoneID(zoneName: "\(recordType)sZone", ownerName: CKCurrentUserDefaultName)
    }
    
    /// recordName : this is the unique identifier for the record, used to locate records on the database. We can create our own ID or leave it to CloudKit to generate a random UUID.
    /// For more: https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda
    public var recordID: CKRecordID {
        guard let sharedSchema = Self.sharedSchema() else { return CKRecordID(recordName: "") }
        guard let primaryKeyProperty = sharedSchema.primaryKeyProperty else { return CKRecordID(recordName: "")}
        
        if let primaryKeyValue = self[primaryKeyProperty.name] as? String {
            return CKRecordID(recordName: primaryKeyValue, zoneID: Self.customZoneID)
        }
        return CKRecordID(recordName: "")
    }
    
    // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
    public var record: CKRecord {
        let r = CKRecord(recordType: Self.recordType, recordID: recordID)
        let properties = objectSchema.properties
        for prop in properties {
            r[prop.name] = self[prop.name] as? CKRecordValue
        }
        return r
    }
    
}


