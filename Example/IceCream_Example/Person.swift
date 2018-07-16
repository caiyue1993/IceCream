//
//  Person.swift
//  IceCream_Example
//
//  Created by 蔡越 on 2018/7/15.
//  Copyright © 2018 蔡越. All rights reserved.
//

import RealmSwift
import IceCream

class Person: Object {
    @objc dynamic var id = NSUUID().uuidString
    @objc dynamic var name = "Jim"
    @objc dynamic var isDeleted = false
    
    override class func primaryKey() -> String? {
        return "id"
    }
}

extension Person: CKRecordConvertible {
    
}

extension Person: CKRecordRecoverable {
    
}
