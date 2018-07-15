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
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var isDeleted = false
    
    static let AVATAR_KEY = "avatar"
    @objc dynamic var avatar: CreamAsset?
    
    // Relationships usage in Realm: https://realm.io/docs/swift/latest/#relationships
    @objc dynamic var owner: Person? // to-one relationships must be optional
    
    override class func primaryKey() -> String? {
        return "id"
    }
}

extension Cat: CKRecordRecoverable {
    
}

extension Cat: CKRecordConvertible {
    
}
