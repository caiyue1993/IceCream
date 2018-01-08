//
//  CreamAsset.swift
//  IceCream
//
//  Created by Fu Yuan on 7/01/18.
//

import Foundation
import RealmSwift
import CloudKit

public class CreamAsset: Object {
    public static let sCreamAssetMark: String = "_CreamAsset"
    //outsie: Read-only
    @objc private(set) public dynamic var path = ""
    ///When chang data, it should also need to create a new path
    @objc private dynamic var data: Data? = nil
    //Ingore data in Realm
    override public static func ignoredProperties() -> [String] {
        return ["data"]
    }
    
    ///This is for recreate a path. The old path will be deleted.
    public func doData(id: String, data: Data) {
        path = "\(id)_\(UUID().uuidString)"
        common(data: data)
    }
    
    func doData(path: String, data: Data) {
        self.path = path
        common(data: data)
    }
    
    private func common(data: Data) {
        self.data = data
        do {
            try self.data!.write(to: URL(fileURLWithPath: CreamAsset.diskCachePath(fileName: path)))
        } catch {
            print("Error writing avatar to temporary directory: \(error)")
        }
    }
    
    public func fetchData() -> Data? {
        return data
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
