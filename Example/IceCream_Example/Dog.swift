//
//  Dog.swift
//  IceCream_Example
//
//  Created by 蔡越 on 23/10/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import RealmSwift
import IceCream
import CloudKit

class Dog: Object {
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
    
    // required for sharing, observing public database
    @objc dynamic var databaseType = DatabaseType.dbPrivate

}

extension Dog: CKRecordConvertible {
    
}

extension Dog: CKRecordRecoverable {
    
}
