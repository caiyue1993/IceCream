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
    associatedtype O: Object
}

extension CKRecordRecoverable {
    func parseFromRecord(record: CKRecord) -> O? {
        let o = O()
        var recordValue: Any?
        for prop in o.objectSchema.properties {
            switch prop.type {
            case .int:
                recordValue = record.value(forKey: prop.name) as? Int
            case .string:
                // Ignore CreamAsset mark id
                if let str = (record.value(forKey: prop.name)) as? String, str.contains(CreamAsset.sCreamAssetMark) {
                    continue
                }
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
            case .object: // only support CKAsset now
                recordValue = objectParse(prop: prop, record: record)
            default:
                print("Other types will be supported in the future.")
            }
            o.setValue(recordValue, forKey: prop.name)
        }
        CreamAsset.removeRedundantCacheFiles(record: record)
        return o
    }
    
    /// Object parse section
    private func objectParse(prop: Property, record: CKRecord) -> Any? {
        if let asset = record.value(forKey: prop.name) as? CKAsset {
            return recordToCreamAsset(prop: prop, record: record, asset: asset)
        } else {
            //Other objects
            return record.value(forKey: prop.name) as? Object
        }
    }
    
    /// CKAsset parse to CreamAsset
    private func recordToCreamAsset(prop: Property, record: CKRecord, asset: CKAsset) -> CreamAsset? {
        var assetPathValue: String?
        
        let assetPathName = prop.name + CreamAsset.sCreamAssetMark
        if record.allKeys().contains(assetPathName) {
            assetPathValue = record.value(forKey: assetPathName) as? String
        }
        guard let assetPath = assetPathValue else {
            return nil
        }
        
        let rawData = NSData(contentsOfFile: asset.fileURL.path) as Data?
        if let assetData = rawData {
            let asset = CreamAsset()
            asset.path = assetPath
            asset.data = assetData
            // Local cache not exist, save it to local files
            if !CreamAsset.diskAllCacheFiles().contains(assetPath) {
                CreamAsset.writeToFile(data: assetData, filePath: CreamAsset.diskCachePath(fileName: assetPath))
            }
            return asset
        }
        return nil
    }
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
        guard let sharedSchema = Self.sharedSchema() else {
            fatalError("No schema settled. Go to Realm Community to seek more help.")
        }
        
        guard let primaryKeyProperty = sharedSchema.primaryKeyProperty else {
            fatalError("You should set a primary key on your Realm object")
        }
        
        if let primaryValueString = self[primaryKeyProperty.name] as? String {
            return CKRecordID(recordName: primaryValueString, zoneID: Self.customZoneID)
        } else if let primaryValueInt = self[primaryKeyProperty.name] as? Int {
            return CKRecordID(recordName: "\(primaryValueInt)", zoneID: Self.customZoneID)
        } else {
            fatalError("Primary key should be String or Int")
        }
    }
    
    // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
    public var record: CKRecord {
        var r = CKRecord(recordType: Self.recordType, recordID: recordID)
        let properties = objectSchema.properties
        for prop in properties {
            print(prop.name)
            switch prop.type {
            case .int, .string, .bool, .date, .float, .double, .data:
                r[prop.name] = self[prop.name] as? CKRecordValue
                break
            case .object:
                r = objcToRecord(r: r, prop: prop)
            default:
                break
            }
            
        }
        return r
    }
    
    private func objcToRecord(r: CKRecord, prop: Property) -> CKRecord {
        if let objClsName = prop.objectClassName, objClsName == CreamAsset.className() {
            let creamAsset = self[prop.name] as? CreamAsset
            var uploadAsset: CKAsset?
            var uploadPath: String = ""
            if let asset = creamAsset {
                let diskCachePath = CreamAsset.diskCachePath(fileName: asset.path)
                // Actually, it impossible as ""
                uploadAsset = asset.path == "" ? nil : CKAsset(fileURL: URL(fileURLWithPath: diskCachePath))
                uploadPath = asset.path
            }
            r[prop.name] = uploadAsset
            r[prop.name + CreamAsset.sCreamAssetMark] = uploadPath as CKRecordValue
        } else {
            //Other object
        }
        return r
    }
    
}


