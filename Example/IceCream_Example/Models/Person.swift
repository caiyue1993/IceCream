//
//  Person.swift
//  IceCream_Example
//
//  Created by 蔡越 on 2018/7/15.
//  Copyright © 2018 蔡越. All rights reserved.
//

import RealmSwift
import CloudKit
import IceCream

class Person: Object {
    @Persisted(primaryKey: true) var id = NSUUID().uuidString
    @Persisted var name = "Jim"
    @Persisted var isDeleted = false

    @Persisted var cats = List<Cat>()
}

extension Person: CKRecordConvertible {
//    static var databaseScope: CKDatabase.Scope {
//        return .public
//    }
}

extension Person: CKRecordRecoverable {
    
}
