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

/// A Realm persistable and IceCream/CloudKit syncronizable Cat
class Cat: Object, Identifiable, ObjectKeyIdentifiable, SoftDeletable, Unfreezable  {
    // NOTE: Remember to make your model objects conform to Identifiable in order to use them in SwiftUI List and ForEach

    @objc dynamic var id = NSUUID().uuidString
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var isDeleted = false
    
    static let AVATAR_KEY = "avatar"
    @objc dynamic var avatar: CreamAsset?
    public var avatar_data: Data? {
        self.avatar?.storedData()
    }

    // Relationships usage in Realm: https://realm.io/docs/swift/latest/#relationships
    @objc dynamic var owner: Person? // to-one relationships must be optional

    override class func primaryKey() -> String? {
        return "id"
    }
}

// MARK: - Convenience query methods

extension Cat {    
    /// Return all cats that have no Owners
    static func allWithNoOwner() -> Results<Cat> {
        return Cat.all.filter("owner == nil or owner.isDeleted = true")
    }
}

// MARK: - Add IceCream / CloudKit Support
extension Cat: CKRecordConvertible, CKRecordRecoverable {
    static var databaseScope: CKDatabase.Scope { .private }
}

