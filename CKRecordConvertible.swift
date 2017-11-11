//
//  Object+CKRecord.swift
//  IceCream
//
//  Created by 蔡越 on 11/11/2017.
//

import Foundation
import CloudKit

public protocol CKRecordConvertible {
    var recordID: CKRecordID { get }
    var record: CKRecord { get }
}

