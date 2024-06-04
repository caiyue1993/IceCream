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
    @Persisted private var uniqueFileName = ""
    override public static func ignoredProperties() -> [String] {
        return ["filePath"]
    }

    private convenience init(objectID: String, propName: String) {
        self.init()
        self.uniqueFileName = "\(objectID)_\(propName)"
    }
    
    /// Use this method to fetch the underlying data of the CreamAsset
    public func storedData() -> Data? {
        return try? Data(contentsOf: filePath)
    }

    /// Where the asset locates in the file system
    public var filePath: URL {
        return CreamAsset.creamAssetDefaultURL().appendingPathComponent(uniqueFileName)
    }

    /// Save the given data to local file system
    /// - Parameters:
    ///   - data: The data to save
    ///   - path:
    ///   - shouldOverwrite: Whether should overwrite current file existed at path or not.
    private static func save(data: Data, to path: String, shouldOverwrite: Bool) throws {
        let url = CreamAsset.creamAssetDefaultURL().appendingPathComponent(path)
        guard shouldOverwrite || !FileManager.default.fileExists(atPath: url.path) else { return }
        try data.write(to: url)
    }

    // MARK: - CKRecordConvertible & CKRecordRecoverable
    
    /// Wrap asset as CKAsset for uploading to CloudKit
    var asset: CKAsset {
        get {
            return CKAsset(fileURL: filePath)
        }
    }

    /// Parses a CKRecord and CKAsset back into a CreamAsset
    ///
    /// - Parameters:
    ///   - propName: The unique property name to identify this asset. e.g.: Dog Object may have multiple CreamAsset properties, so we need unique `propName`s to identify these.
    ///   - record: The CKRecord where we will pull the record ID off of to locate/store the file
    ///   - asset: The CKAsset where we will pull the URL for creating the asset
    /// - Returns: A CreamAsset if it was successful
    static func parse(from propName: String, record: CKRecord, asset: CKAsset) -> CreamAsset? {
        guard let url = asset.fileURL else { return nil }
        return CreamAsset.create(objectID: record.recordID.recordName,
                                 propName: propName,
                                 url: url,
                                 shouldOverwrite: true)
    }

    // MARK: - Factory methods
    
    /// Creates a new CreamAsset for the given object id with Data
    ///
    /// - Parameters:
    ///   - objectID: The objectID (key property of the Realm object) the asset will be identified by
    ///   - propName: The unique property name to identify this asset. e.g.: Dog Object may have multiple CreamAsset properties, so we need unique `propName`s to identify these.
    ///   - data: The file data
    ///   - shouldOverwrite: Whether to try and save the file even if an existing file exists for the same object ID.
    /// - Returns: A CreamAsset if it was successful
    public static func create(objectID: String, propName: String, data: Data, shouldOverwrite: Bool = true) -> CreamAsset? {
        let creamAsset = CreamAsset(objectID: objectID,
                                    propName: propName)
        do {
            try save(data: data, to: creamAsset.uniqueFileName, shouldOverwrite: shouldOverwrite)
            return creamAsset
        } catch {
            // Os.log error here
            return nil
        }
    }
    
    /// Creates a new CreamAsset for the given object with Data
    ///
    /// - Parameters:
    ///   - object: The object the asset will live on
    ///   - propName: The unique property name to identify this asset. e.g.: Dog Object may have multiple CreamAsset properties, so we need unique `propName`s to identify these.
    ///   - data: The file data
    ///   - shouldOverwrite: Whether to try and save the file even if an existing file exists for the same object.
    /// - Returns: A CreamAsset if it was successful
    public static func create(object: CKRecordConvertible, propName: String, data: Data, shouldOverwrite: Bool = true) -> CreamAsset? {
        return create(objectID: object.recordID.recordName,
                      propName: propName,
                      data: data,
                      shouldOverwrite: shouldOverwrite)
    }

    /// Creates a new CreamAsset for the given object with a URL
    ///
    /// - Parameters:
    ///   - object: The object the asset will live on
    ///   - propName: The unique property name to identify this asset. e.g.: Dog Object may have multiple CreamAsset properties, so we need unique `propName`s to identify these.
    ///   - url: The URL where the file located
    ///   - shouldOverwrite: Whether to try and save the file even if an existing file exists for the same object.
    /// - Returns: A CreamAsset if it was successful
    public static func create(object: CKRecordConvertible, propName: String, url: URL, shouldOverwrite: Bool = true) -> CreamAsset? {
        return create(objectID: object.recordID.recordName,
                      propName: propName,
                      url: url,
                      shouldOverwrite: shouldOverwrite)
    }
    
    
    /// Creates a new CreamAsset for the given objectID with a URL where asset locates
    /// - Parameters:
    ///   - objectID: The key to identify the object. Normally it's the recordName property of CKRecord.ID when recovering from CloudKit
    ///   - propName: The unique property name to identify this asset. e.g.: Dog Object may have multiple CreamAsset properties, so we need unique `propName`s to identify these.
    ///   - url: The location where asset locates
    ///   - shouldOverwrite: Whether to try and save the file even if an existing file exists for the same object.
    /// - Returns: The CreamAsset if creates successful
    public static func create(objectID: String, propName: String, url: URL, shouldOverwrite: Bool = true) -> CreamAsset? {
        let creamAsset = CreamAsset(objectID: objectID, propName: propName)
        if shouldOverwrite {
            do {
                try FileManager.default.removeItem(at: creamAsset.filePath)
            } catch {
                // Os.log remove item failed error here
            }
        }
        if !FileManager.default.fileExists(atPath: creamAsset.filePath.path) {
            do {
                try FileManager.default.copyItem(at: url, to: creamAsset.filePath)
            } catch {
                /// Os.log copy item failed
                return nil
            }
        }
        return creamAsset
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
                /// Log: create directory failed
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
                try FileManager.default.removeItem(atPath: absolutePath)
            } catch {
                /// Log: remove item failed at given path
            }
        }
    }

    /// When delete an object. We need to delete related CreamAsset files
    public static func deleteCreamAssetFile(with id: String) {
        let needToDeleteCacheFiles = creamAssetFilesPaths().filter { $0.contains(id) }
        excecuteDeletions(in: needToDeleteCacheFiles)
    }

}
