//
//  Cat.swift
//  IceCream_Example
//
//  Created by 蔡越 on 22/05/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import Foundation
import RealmSwift
import IceCream
import CloudKit

class Cat: Object {
    @objc dynamic var id = NSUUID().uuidString
    @objc dynamic var name = "ShiWan"
    @objc dynamic var age = 1
    @objc dynamic var isDeleted = false
    
    override class func primaryKey() -> String? {
        return "id"
    }
}

extension Cat: CKRecordRecoverable {
    
}

extension Cat: CKRecordConvertible {
    
}
