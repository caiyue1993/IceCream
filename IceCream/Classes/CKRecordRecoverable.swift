//
//  CKRecordRecoverable.swift
//  IceCream
//
//  Created by 蔡越 on 26/05/2018.
//

import CloudKit
import RealmSwift

public protocol CKRecordRecoverable {
    
}

extension CKRecordRecoverable where Self: Object {
    func parseFromRecord(record: CKRecord, realm: Realm) -> Self? {
        let o = Self()
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
                if let asset = record.value(forKey: prop.name) as? CKAsset {
                    recordValue = CreamAsset.parse(from: prop.name, record: record, asset: asset)
                } else if let owner = record.value(forKey: prop.name) as? CKRecord.Reference, let ownerType = prop.objectClassName {
                    recordValue = realm.dynamicObject(ofType: ownerType, forPrimaryKey: owner.recordID.recordName)
                    // Because we use the primaryKey as recordName when object converting to CKRecord
                }
            default:
                print("Other types will be supported in the future.")
            }
            o.setValue(recordValue, forKey: prop.name)
        }
        return o
    }
}
