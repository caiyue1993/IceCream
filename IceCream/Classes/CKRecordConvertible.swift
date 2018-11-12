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
    static var customZoneID: CKRecordZone.ID { get }
    
    var recordID: CKRecord.ID { get }
    var record: CKRecord { get }
    
    var isDeleted: Bool { get }
}

extension CKRecordConvertible where Self: Object {
    
    public static var recordType: String {
        return className()
    }
    
    public static var customZoneID: CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: "\(recordType)sZone", ownerName: CKCurrentUserDefaultName)
    }
    
    /// recordName : this is the unique identifier for the record, used to locate records on the database. We can create our own ID or leave it to CloudKit to generate a random UUID.
    /// For more: https://medium.com/@guilhermerambo/synchronizing-data-with-cloudkit-94c6246a3fda
    public var recordID: CKRecord.ID {
        guard let sharedSchema = Self.sharedSchema() else {
            fatalError("No schema settled. Go to Realm Community to seek more help.")
        }
        
        guard let primaryKeyProperty = sharedSchema.primaryKeyProperty else {
            fatalError("You should set a primary key on your Realm object")
        }
        
        if let primaryValueString = self[primaryKeyProperty.name] as? String {
            return CKRecord.ID(recordName: primaryValueString, zoneID: Self.customZoneID)
        } else if let primaryValueInt = self[primaryKeyProperty.name] as? Int {
            return CKRecord.ID(recordName: "\(primaryValueInt)", zoneID: Self.customZoneID)
        } else {
            fatalError("Primary key should be String or Int")
        }
    }
    
    // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
    public var record: CKRecord {
        let r = CKRecord(recordType: Self.recordType, recordID: recordID)
        let properties = objectSchema.properties
        for prop in properties {
            
            let item = self[prop.name]
            
            if prop.isArray {
                switch prop.type {
                case .int:
                    guard let list = item as? List<Int>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                case .string:
                    guard let list = item as? List<String>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                case .bool:
                    guard let list = item as? List<Bool>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                case .float:
                    guard let list = item as? List<Float>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                case .double:
                    guard let list = item as? List<Double>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                case .data:
                    guard let list = item as? List<Data>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                case .date:
                    guard let list = item as? List<Date>, !list.isEmpty else { break }
                    let array = Array(list)
                    r[prop.name] = array as CKRecordValue
                default:
                    break
                    /// Other inner types of List is not supported yet
                }
                continue
            }
            
            switch prop.type {
            case .int, .string, .bool, .date, .float, .double, .data:
                r[prop.name] = item as? CKRecordValue
            case .object:
                guard let objectName = prop.objectClassName else { break }
                // If object is CreamAsset, set record with its wrapped CKAsset value
                if objectName == CreamAsset.className(), let creamAsset = item as? CreamAsset {
                    r[prop.name] = creamAsset.asset
                } else if let owner = item as? CKRecordConvertible {
                    // Handle to-one relationship: https://realm.io/docs/swift/latest/#many-to-one
                    // So the owner Object has to conform to CKRecordConvertible protocol
                    r[prop.name] = CKRecord.Reference(recordID: owner.recordID, action: .none)
                } else {
                    /// Just a warm hint:
                    /// When we set nil to the property of a CKRecord, that record's property will be hidden in the CloudKit Dashboard
                    r[prop.name] = nil
                }
                // To-many relationship is not supported yet.
            default:
                break
            }
            
        }
        return r
    }
    
}


