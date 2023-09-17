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
    @Persisted(primaryKey: true) var id = NSUUID().uuidString
    @Persisted var name = ""
    @Persisted var age = 0
    @Persisted var isDeleted = false

    static let AVATAR_KEY = "avatar"
    @Persisted var avatar: CreamAsset?
}

extension Cat: CKRecordRecoverable {
    
}

extension Cat: CKRecordConvertible {
    
}
