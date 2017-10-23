

import Foundation
import RealmSwift

final class Cream {
    
    private let realm: Realm
    static let shared = Cream()
    
    init(realm: Realm?) {
        if let r = realm { self.realm = r }
        else { self.realm = try! Realm() }
    }
    
    public convenience init() {
        self.init(realm: nil)
    }
    
    private func insertOrUpdate<T: Object>(object: T) throws {
        guard let primaryKey = T.primaryKey() else {
            fatalError("Can not execute insertOrUpdate when no primaryKey in \(T.description())")
        }
        
        guard let primaryKeyValue = object.value(forKey: primaryKey) else {
            fatalError("Can not find the given primaryKey value of \(T.description())")
        }
        
        if let _ = realm.object(ofType: T.self, forPrimaryKey: primaryKeyValue) {
            realm.beginWrite()
            realm.add(object, update: true)
            try realm.commitWrite()
        } else {
            realm.beginWrite()
            realm.add(object)
            try realm.commitWrite()
        }
    }
}

