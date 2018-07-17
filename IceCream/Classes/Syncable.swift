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
    func add(record: CKRecord)
    func delete(recordID: CKRecord.ID)
    
    /// Callback
    var pipeToEngine: ((_ recordsToStore: [CKRecord], _ recordIDsToDelete: [CKRecord.ID]) -> ())? { get set }
}
