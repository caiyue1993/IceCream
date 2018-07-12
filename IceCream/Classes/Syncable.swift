//
//  Syncable.swift
//  IceCream
//
//  Created by 蔡越 on 24/05/2018.
//

import Foundation
import CloudKit

/// Since `sync` is an informal version of `synchronize`, so we choose the `syncable` word for
/// the ability of synchronization.
public protocol Syncable: class {
    
    /// CKRecordZone related
    var recordType: String { get }
    var customZoneID: CKRecordZone.ID { get }
    
    /// Local storage
    var zoneChangesToken: CKServerChangeToken? { get set }
    var isCustomZoneCreated: Bool { get }
    
    /// Realm Database related
    func registerLocalDatabase()
    func cleanUp()
    func add(databaseType: DatabaseType, record: CKRecord)
    func delete(recordID: CKRecord.ID)
 
    ///
    /// Upon observing changes originating locally, send the changes to CloudKit
    /// - Parameters:
    ///   - recordsToStore: An array of all
    var pipeToEngine: ((_ recordsToStore: [CKRecord], _ recordIDsToDelete: [CKRecord.ID]) -> ())? { get set }
}
