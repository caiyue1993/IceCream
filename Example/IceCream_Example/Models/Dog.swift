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
    @Persisted(primaryKey: true) var id = NSUUID().uuidString
    @Persisted var name = ""
    @Persisted var age = 0
    @Persisted var isDeleted = false

    static let AVATAR_KEY = "avatar"
    @Persisted var avatar: CreamAsset?

    // Relationships usage in Realm: https://realm.io/docs/swift/latest/#relationships
    @Persisted var owner: Person? // to-one relationships must be optional
}

extension Dog: CKRecordConvertible {
    
}

extension Dog: CKRecordRecoverable {
    
}
