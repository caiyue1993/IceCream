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
import Combine

/// A Realm persistable and IceCream/CloudKit syncronizable Person (cat owner)
final class Person: Object, Identifiable, ObjectKeyIdentifiable, SoftDeletable, Unfreezable  {
    // NOTE: Remember to make your model objects conform to Identifiable in order to use them in SwiftUI List and ForEach
    @objc dynamic var id = NSUUID().uuidString
    @objc dynamic var name = "Jim"
    @objc dynamic var isDeleted = false
    
    var cats = LinkingObjects(fromType: Cat.self, property: "owner")
    
    override class func primaryKey() -> String? {
        return "id"
    }
}

// MARK: - Convenience methods

extension Person {
    /// Return all owned cats
    func listOfCats() -> AnyRealmCollection<Cat> {
        return AnyRealmCollection(self.cats.filter("isDeleted == false").sorted(byKeyPath: "name"))
    }
    
    /// Return all owned cats in a way that can be used as a SwiftUI @ObservedObject
    func observableListOfCats() -> BindableResults<Cat> {
        return BindableResults(self.cats.filter("isDeleted == false").sorted(byKeyPath: "name"))
    }
    
    /// Cascading 'soft delete' of a persons and all owned cats
    func cascadingDelete() {
        realmWrite { realm in
            cats.setValue(true, forKey: "isDeleted")
            self.isDeleted = true
        }
    }
    
    /// Add a cat and persist it to Realm
    func addCat(cat: Cat) {
        realmWrite { realm in
            cat.owner = self
        }
    }
    
    static func allWithNoCats() -> Results<Person> {
        return Person.all.filter("cats.@count == 0") // TODO: Check if cats are deleted
    }
}

// MARK: - Add IceCream / CloudKit Support
extension Person: CKRecordConvertible, CKRecordRecoverable {
    static var databaseScope: CKDatabase.Scope { .private }
}



