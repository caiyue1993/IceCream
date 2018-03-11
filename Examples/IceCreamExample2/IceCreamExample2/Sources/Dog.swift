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

protocol AnimalProtocol {
    var id: String  { get set }
    var name: String { get set }
    var age: Int { get set }
    var isDeleted: Bool { get set }
}


class Animal: Object, AnimalProtocol {
    @objc dynamic var id: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var age: Int = 0
    @objc dynamic var isDeleted: Bool = false
    
    static let AVATAR_KEY = "avatar"
    @objc dynamic var avatar: CreamAsset?

    convenience init(age: Int) {
        self.init()
        self.age = age
    }

    override static func primaryKey() -> String {
        return "id"
    }
}

class Dog: Animal {
    
    convenience init(name: String, age: Int) {
        self.init(age: age)
        
        self.id = IceCream.id(typeName: "Dog", uuid: UUID().uuidString)
        let leaving4 = self.id.count - 4
        self.name = "\(name) \(self.id.dropFirst(leaving4))"
    }
}

extension Dog: CKRecordConvertible {
}

class Cat: Animal {
    convenience init(name: String, age: Int) {
        self.init(age: age)
        
        self.id = IceCream.id(typeName: "Cat", uuid: UUID().uuidString)
        let leaving4 = self.id.count - 4
        self.name = "\(name) \(self.id.dropFirst(leaving4))"
    }
}

extension Cat: CKRecordConvertible {
}



