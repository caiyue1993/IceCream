//
//  Dog.swift
//  IceCream_Example
//
//  Created by 蔡越 on 23/10/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import RealmSwift
import IceCream
import CloudKit

class Dog: Object, Codable {
    @objc dynamic var id = NSUUID().uuidString
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var isDeleted = false
    
    override class func primaryKey() -> String? {
        return "id"
    }
}

extension Dog: CKRecordConvertible {
    /// recordName : this is the unique identifier for the record, used to locate records on the database. We can create our own ID or leave it to CloudKit to generate a random UUID.
    /// For more: https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda
    var recordID: CKRecordID {
        return CKRecordID(recordName: id, zoneID: Dog.customZoneID)
    }
    
    var record: CKRecord {
        // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
        let r = CKRecord(recordType: Dog.recordType, recordID: recordID)
        r[.id] = id as CKRecordValue
        r[.age] = age as CKRecordValue
        r[.name] = name as CKRecordValue
        r[.isDeleted] = isDeleted as CKRecordValue
        return r
    }
    
    static var customZoneID: CKRecordZoneID {
        return CKRecordZoneID(zoneName: "DogsZone", ownerName: CKCurrentUserDefaultName)
    }
    
}

extension Dog: CKRecordRecoverable {
    static func objectFrom(record: CKRecord) -> Object? {
        guard let id = record[.id] as? String,
            let age = record[.age] as? Int,
            let name = record[.name] as? String,
            let isDeleted = record[.isDeleted] as? Bool
            else { return nil }
        
        let dog = Dog()
        dog.id = id
        dog.age = age
        dog.name = name
        dog.isDeleted = isDeleted
        
        return dog
    }
}

enum DogKey: String {
    case id
    case name
    case age
    case isDeleted
}

extension CKRecord {
    subscript(_ key: DogKey) -> CKRecordValue {
        get {
            return self[key.rawValue]!
        }
        set {
            self[key.rawValue] = newValue
        }
    }
}
