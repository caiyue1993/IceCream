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
    static var zoneID: CKRecordZone.ID { get }
    static var databaseScope: CKDatabase.Scope { get }
    
    var recordID: CKRecord.ID { get }
    var record: CKRecord { get }

    var isDeleted: Bool { get }
}

extension CKRecordConvertible where Self: Object {
    
    public static var databaseScope: CKDatabase.Scope {
        return .private
    }
    
    public static var recordType: String {
        return className()
    }
    
    public static var zoneID: CKRecordZone.ID {
        switch Self.databaseScope {
        case .private:
            return CKRecordZone.ID(zoneName: "\(recordType)sZone", ownerName: CKCurrentUserDefaultName)
        case .public:
            return CKRecordZone.default().zoneID
        default:
            fatalError("Shared Database is not supported now")
        }
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
        
        switch primaryKeyProperty.type {
        case .string:
            if var primaryValueString = self[primaryKeyProperty.name] as? String {
                // For more: https://developer.apple.com/documentation/cloudkit/ckrecord/id/1500975-init
                
                // Remove any emojis if they exist as a key by accident
                // this isn't ideal, but it's better than crashing if an
                // emoji is accidentally added
                if (!primaryValueString.allSatisfy({ $0.isASCII })) {
                    primaryValueString = primaryValueString.stringByRemovingEmoji()
                }
                
                assert(primaryValueString.allSatisfy({ $0.isASCII }), "Primary value for CKRecord name must contain only ASCII characters")
                assert(primaryValueString.count <= 255, "Primary value for CKRecord name must not exceed 255 characters")
                assert(!primaryValueString.starts(with: "_"), "Primary value for CKRecord name must not start with an underscore")
                return CKRecord.ID(recordName: primaryValueString, zoneID: Self.zoneID)
            } else {
                assertionFailure("\(primaryKeyProperty.name)'s value should be String type")
            }
        case .int:
            if let primaryValueInt = self[primaryKeyProperty.name] as? Int {
                return CKRecord.ID(recordName: "\(primaryValueInt)", zoneID: Self.zoneID)
            } else {
                assertionFailure("\(primaryKeyProperty.name)'s value should be Int type")
            }
        default:
            assertionFailure("Primary key should be String or Int")
        }
        fatalError("Should have a reasonable recordID")
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
                case .object:
                    /// We may get List<Cat> here
                    /// The item cannot be casted as List<Object>
                    /// It can be casted at a low-level type `ListBase`
                    guard let list = item as? ListBase, list.count > 0 else { break }
                    var referenceArray = [CKRecord.Reference]()
                    let wrappedArray = list._rlmArray
                    for index in 0..<wrappedArray.count {
                        guard let object = wrappedArray[index] as? Object, let primaryKey = object.objectSchema.primaryKeyProperty?.name else { continue }
                        switch object.objectSchema.primaryKeyProperty?.type {
                        case .string:
                            if let primaryValueString = object[primaryKey] as? String, let obj = object as? CKRecordConvertible, !obj.isDeleted {
                                let referenceZoneID = CKRecordZone.ID(zoneName: "\(object.objectSchema.className)sZone", ownerName: CKCurrentUserDefaultName)
                                referenceArray.append(CKRecord.Reference(recordID: CKRecord.ID(recordName: primaryValueString, zoneID: referenceZoneID), action: .none))
                            }
                        case .int:
                            if let primaryValueInt = object[primaryKey] as? Int, let obj = object as? CKRecordConvertible, !obj.isDeleted {
                                let referenceZoneID = CKRecordZone.ID(zoneName: "\(object.objectSchema.className)sZone", ownerName: CKCurrentUserDefaultName)
                                referenceArray.append(CKRecord.Reference(recordID: CKRecord.ID(recordName: "\(primaryValueInt)", zoneID: referenceZoneID), action: .none))
                            }
                        default:
                            break
                        }
                    }
                    r[prop.name] = referenceArray as CKRecordValue
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
            default:
                break
            }
            
        }
        return r
    }
    
}

extension String {
  func stringByRemovingEmoji() -> String {
    return String(self.filter { !$0.isEmoji() })
  }
}

extension Character {
  fileprivate func isEmoji() -> Bool {
    return Character(UnicodeScalar(UInt32(0x1d000))!) <= self && self <= Character(UnicodeScalar(UInt32(0x1f77f))!)
      || Character(UnicodeScalar(UInt32(0x2100))!) <= self && self <= Character(UnicodeScalar(UInt32(0x26ff))!)
  }
}
