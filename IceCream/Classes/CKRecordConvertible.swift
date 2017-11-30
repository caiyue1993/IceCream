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
    
    static func objectFrom(record: CKRecord) -> Object?
    
}

extension CKRecordConvertible where Self: Object {
    
    public static func parseSchema() {
        if let sharedSchema = Self.sharedSchema() {
            print(sharedSchema)
        }
    }
    
    public static var recordType: String {
        return Self.className()
    }
    
}

