//
//  Dog+CKRecord.swift
//  IceCream_Example
//
//  Created by 蔡越 on 11/11/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import CloudKit
import RealmSwift

enum DogKey: String {
    case id
    case name
    case age
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

extension Dog {
    var recordID: CKRecordID {
        return CKRecordID(recordName: id)
    }
    
    var record: CKRecord {
        let r = CKRecord(recordType: "Dog", recordID: recordID)
        r[.id] = id as CKRecordValue
        r[.age] = age as CKRecordValue
        r[.name] = name as CKRecordValue
        return r
    }
}
