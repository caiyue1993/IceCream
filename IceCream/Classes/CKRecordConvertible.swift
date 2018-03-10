//
//  Object+CKRecord.swift
//  IceCream
//
//  Created by 蔡越 on 11/11/2017.
//

import Foundation
import CloudKit
import RealmSwift
import Realm

public protocol CKRecordConvertible {
    var isDeleted: Bool { get }
}

public protocol CKRecordRecoverable {
    
}

struct CloudKitToObject {
    
    static func object<O: Object>(ofType: O.Type, withRecord record: CKRecord) -> O? {
        let o = ofType.init()
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

public protocol StoredInPublicDatabase {
}
