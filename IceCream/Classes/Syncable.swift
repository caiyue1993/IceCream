//
//  Syncable.swift
//  IceCream
//
//  Created by 蔡越 on 24/05/2018.
//

import Foundation
import CloudKit

/// Since `sync` is an informal version of `synchronize`, so we choose the `syncable` word for
/// the ability to put objects into sync.
public protocol Syncable: class {
    
    var recordType: String { get }
    var customZoneID: CKRecordZoneID { get }
    
    var zoneChangesToken: CKServerChangeToken? { get set }
   
    var isCustomZoneCreated: Bool { get }
    
    func registerLocalDatabase()
    func cleanUp()
    func add(record: CKRecord)
    func delete(recordID: CKRecordID)
    
    var pipeToEngine: ((_ recordsToStore: [CKRecord], _ recordIDsToDelete: [CKRecordID]) -> ())? { get set }
}
