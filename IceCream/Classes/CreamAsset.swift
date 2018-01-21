//
//  CreamAsset.swift
//  IceCream
//
//  Created by Fu Yuan on 7/01/18.
//

import Foundation
import RealmSwift
import Realm
import CloudKit

/// If you want to store and sync big data automatically, then using CreamAsset might be a good choice.
/// According to Apple https://developer.apple.com/documentation/cloudkit/ckasset :
/// "You can also use assets in places where the data you want to assign to a field is more than a few kilobytes in size. "
/// And According to Realm https://realm.io/docs/objc/latest/#current-limitations :
/// "Data and String properties cannot hold data exceeding 16MB in size. To store larger amounts of data, either break it up into 16MB chunks or store it directly on the file system, storing paths to these files in the Realm. An exception will be thrown at runtime if your app attempts to store more than 16MB in a single property."
/// We choose the latter, that's storing it directly on the file system, storing paths to these files in the Realm.
/// So this is the deal.
public class CreamAsset: Object {
    public static let sCreamAssetMark: String = "_CreamAsset"
    
    @objc dynamic var uniqueFileName = ""
    @objc dynamic var data: Data?
    override public static func ignoredProperties() -> [String] {
        return ["data"]
    }
    
    public convenience init(uniqueKey: String, data: Data) {
        self.init()
        self.data = data
        self.uniqueFileName = "\(uniqueKey)_\(UUID().uuidString)"
        save(data: data, to: uniqueFileName)
    }
    
    func save(data: Data, to path: String) {
        let url = CreamAsset.creamAssetDefaultURL().appendingPathComponent(path)
        do {
            try data.write(to: url)
        } catch {
            print("Error writing avatar to temporary directory: \(error)")
        }
    }
    
    public func getData() -> Data? {
        if data != nil {
            return data
        }
        let filePath = CreamAsset.creamAssetDefaultURL().appendingPathComponent(uniqueFileName)
        return try! Data(contentsOf: filePath)
    }
    
    var asset: CKAsset {
        get {
            let diskCachePath = CreamAsset.creamAssetDefaultURL().appendingPathComponent(uniqueFileName)
            let uploadAsset = CKAsset(fileURL: diskCachePath)
            return uploadAsset
        }
    }
    
    static func parse(from propName: String, record: CKRecord, asset: CKAsset) -> CreamAsset? {
        let assetPathKey = propName + CreamAsset.sCreamAssetMark
        guard let assetPathValue = record.value(forKey: assetPathKey) as? String else { return nil }
        guard let assetData = NSData(contentsOfFile: asset.fileURL.path) as Data? else { return nil }
        let asset = CreamAsset()
        asset.uniqueFileName = assetPathValue
        asset.data = assetData
        // Local cache not exist, save it to local files
        if !CreamAsset.creamAssetFilesPaths().contains(assetPathValue) {
            try! assetData.write(to: creamAssetDefaultURL().appendingPathComponent(assetPathValue))
        }
        return asset
    }
}

extension CreamAsset {
    /// The default path for the storing of CreamAsset. That is:
    /// xxx/Document/CreamAsset/
    public static func creamAssetDefaultURL() -> URL {
        let documentDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let commonAssetPath = documentDir.appendingPathComponent(className())
        if !FileManager.default.fileExists(atPath: commonAssetPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: commonAssetPath.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                
            }
        }
        return commonAssetPath
    }
    
    /// Fetch all CreamAsset files' path
    public static func creamAssetFilesPaths() -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: CreamAsset.creamAssetDefaultURL().path)
        } catch {
            
        }
        return [String]()
    }
    
    /// Execute deletions
    private static func excecuteDeletions(in filesNames: [String]) {
        for fileName in filesNames {
            let absolutePath = CreamAsset.creamAssetDefaultURL().appendingPathComponent(fileName).path
            do {
                print("deleteCacheFiles.removeItem:", absolutePath)
                try FileManager.default.removeItem(atPath: absolutePath)
            } catch {
                
            }
        }
    }
    
    /// When delete an object. We need to delete related CreamAsset files
    public static func deleteCreamAssetFile(with id: String) {
        let needToDeleteCacheFiles = creamAssetFilesPaths().filter { $0.contains(id) }
        excecuteDeletions(in: needToDeleteCacheFiles)
    }
    
    /// This step will only delete the local files which are not exist in iCloud. CKRecord to compare with local cache files, continue to keep local files which iCloud's record are still exists.
    public static func removeRedundantCacheFiles(record: CKRecord) {
        DispatchQueue.global(qos: .background).async {
            let idForThisRecord: String = record.value(forKey: "id") as! String
            /// Which must have value in iCloud
            var allCloudAssetStringValues = [String]()
            /// Local files, which must relate with this record's id
            var allLocalRelateCacheFiles = [String]()
            
            // Get all iCloud exist files' name
            let allKeys = record.allKeys()
            for key in allKeys {
                if key.contains(CreamAsset.sCreamAssetMark) {
                    let valueA = record.value(forKey: key) as? String
                    if let value = valueA, value != "" {
                        allCloudAssetStringValues.append(value)
                    }
                }
            }
            let allCacheFiles = creamAssetFilesPaths()
            for fileName in allCacheFiles {
                if fileName.contains(idForThisRecord) {
                    allLocalRelateCacheFiles.append(fileName)
                }
            }
            var needToDeleteCacheFiles = [String]()
            for cacheFile in allLocalRelateCacheFiles {
                if !allCloudAssetStringValues.contains(cacheFile) {
                    needToDeleteCacheFiles.append(cacheFile)
                }
            }
            
            excecuteDeletions(in: needToDeleteCacheFiles)
        }
    }
}
