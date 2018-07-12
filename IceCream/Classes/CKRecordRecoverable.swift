//
//  CKRecordRecoverable.swift
//  IceCream
//
//  Created by 蔡越 on 26/05/2018.
//

import CloudKit
import RealmSwift

@objc public enum DatabaseType: Int {
    case dbPrivate, dbShared
    func description() -> String {
        switch self {
        case .dbPrivate:
            return "dbPrivate"
        case .dbShared:
            return "dbShared"
        }
    }
    func dataBase() -> CKDatabase {
        let container = CKContainer.default()
        switch self {
        case .dbPrivate:
            return container.privateCloudDatabase
        case .dbShared:
            return container.sharedCloudDatabase
        }
    }
}

public protocol CKRecordRecoverable {
    var databaseType: DatabaseType { get set }
}

extension CKRecordRecoverable where Self: Object {
    func parseFromRecord(record: CKRecord) -> Self? {
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
