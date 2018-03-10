//
//  ObjectTypeRegister.swift
//  IceCream
//
//  Created by Andrew Eades on 10/03/2018.
//

import Foundation
import RealmSwift
import CloudKit

struct ObjectTypeRegister {
    static var entries = ObjectTypeRegister()
    
    private var _entries: [String : Object.Type] = [:]
    
    subscript(_ name: String) ->  Object.Type? {
        get {
            return _entries[name]
        }
        set {
            _entries[name] = newValue
        }
    }
    
    subscript(_ record: CKRecord) -> Object.Type? {
        get {
            let name = record.recordType
            
            return _entries[name]
        }
    }
    
    subscript(_ recordID: CKRecordID) -> Object.Type? {
        let name: String
        
        let splits = recordID.recordName.split(separator: ":")
        if splits.count > 1, splits[0] == "IceCream" {
            name = String(splits[1])
        } else if recordID.zoneID.zoneName.hasSuffix("sZone") {
            name = String(recordID.zoneID.zoneName.dropLast(5))
        } else {
            print("Unable to derive object type from recordID")
            return nil
        }
        
        return _entries[name]
    }
}
