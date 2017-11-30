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
    
    static func objectFrom(record: CKRecord) -> Object?
    
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
    
    public var record: CKRecord {
        let r = CKRecord(recordType: Self.recordType, recordID: recordID)
        guard let sharedSchema = Self.sharedSchema() else { return r }
        let properties = sharedSchema.properties
        
        return CKRecord(recordType: "")
    }
    
}

