//
//  CKRecordRecoverable.swift
//  IceCream
//
//  Created by 蔡越 on 26/05/2018.
//

import Foundation
import CloudKit
import RealmSwift

public protocol CKRecordRecoverable: CKRecordConnectable
{
}

extension CKRecordRecoverable where Self: Object
{
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
				if let asset = record.value(forKey: prop.name) as? CKAsset
				{
					recordValue = CreamAsset.parse(from: prop.name, record: record, asset: asset)
				}
				else if let reference = record.value(forKey: prop.name) as? CKRecord.Reference
				{
					var objectType: Object.Type?
					guard let referencesTypes = Self.references else { break }
					for referenceType in referencesTypes
					{
						if prop.objectClassName == referenceType.className() { objectType = referenceType }
					}
					guard let type = objectType,
						let primaryKey = type.primaryKey() else { break }
					
						let object = self.realm?.objects(type).filter("%K == %@", primaryKey, reference.recordID.recordName)
					recordValue = object
				}
			default:
				print(prop)
            }
            o.setValue(recordValue, forKey: prop.name)
        }
        return o
    }
}
