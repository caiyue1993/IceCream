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

public class CreamAsset: Object {
    public static let sCreamAssetMark: String = "_CreamAsset"
    
    @objc dynamic var path = ""
    @objc dynamic var data: Data?
    
    override public static func ignoredProperties() -> [String] {
        return ["data"]
    }
    
    private var uniqueKey: String = ""
    
    public convenience init(uniqueKey: String, data: Data) {
        self.init()
        self.uniqueKey = uniqueKey
        self.data = data
        
        self.path = "\(uniqueKey)_\(UUID().uuidString)"
        save(data: data, to: path)
    }
    
    func save(data: Data, to path: String) {
        let url = URL(fileURLWithPath: CreamAsset.diskCachePath(fileName: path))
        do {
            try data.write(to: url)
        } catch {
            print("Error writing avatar to temporary directory: \(error)")
        }
    }
    
    public func fetchData() -> Data? {
        if self.data != nil {
            return self.data
        }
        let filePath = CreamAsset.diskCachePath(fileName: self.path)
        return NSData(contentsOfFile: filePath) as Data?
    }
}

extension CreamAsset {
    
    ///According to file name to create cache file path
    public static func diskCachePath(fileName: String) -> String {
        let dcPath = diskCacheFolder() as NSString
        return dcPath.appendingPathComponent(fileName)
    }
    
    ///Fetch the cache file folder
    public static func diskCacheFolder() -> String {
        let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString
        let folderPath = docPath.appendingPathComponent("IceCreamCacheFiles")
        if FileManager.default.fileExists(atPath: folderPath) == false {
            do{
                try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: false, attributes: nil)
            }catch{
            }
        }
        return folderPath
    }
    
    ///Fetch all cache files
    public static func diskAllCacheFiles() -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: CreamAsset.diskCacheFolder())
        } catch  {
        }
        return [String]()
    }
    
    ///Execute delete
    private static func doDelete(files: [String]){
        for fileName in files {
            let absolutePath = CreamAsset.diskCachePath(fileName: fileName)
            do {
                print("deleteCacheFiles.removeItem:", absolutePath)
                try FileManager.default.removeItem(atPath: absolutePath)
            } catch {
                print(error)
            }
        }
    }
    
    ///When delete an object. Delete related cache files
    public static func deleteCacheFiles(id: String) {
        var needToDeleteCacheFiles = [String]()
        let allCacheFiles = diskAllCacheFiles()
        for fileName in allCacheFiles {
            if fileName.contains(id) {
                needToDeleteCacheFiles.append(fileName)
            }
        }
        doDelete(files: needToDeleteCacheFiles)
    }
    
    ///This step will only delete the local files which are not exist in iCloud. CKRecord to compare with local cache files, continue to keep local files which iCloud's record are still exists. 
    public static func removeRedundantCacheFiles(record: CKRecord) {
        DispatchQueue.global(qos: .background).async {
            let idForThisRecord: String = record.value(forKey: "id") as! String
            ///Which must have value in iCloud
            var allCloudAssetStringValues = [String]()
            ///Local files, which must relate with this record's id
            var allLocalRelateCacheFiles = [String]()
            
            //Get all iCloud exist files' name
            let allKeys = record.allKeys()
            for key in allKeys {
                if key.contains(CreamAsset.sCreamAssetMark) {
                    let valueA = record.value(forKey: key) as? String
                    if let value = valueA, value != "" {
                        allCloudAssetStringValues.append(value)
                    }
                }
            }
            let allCacheFiles = diskAllCacheFiles()
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
            
            doDelete(files: needToDeleteCacheFiles)
        }
    }
    
    public static func writeToFile(data: Data, filePath: String){
        do {
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
            print("Write, Error:\(error)")
        }
    }
}
