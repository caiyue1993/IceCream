import Foundation
import RealmSwift

/// Cream is the Alfred of Realm.
/// You do insert/update/delete with Cream instead of manipulating Realm itself.

public final class Cream {
    
    /// The original realm that Cream dances with.
    let realm: Realm
    
    // MARK: - Singleton
    public static let shared = Cream()
    
    // MARK: - Initializer
    init(realm: Realm? = nil) {
        if let r = realm {
            self.realm = r
        } else {
            self.realm = try! Realm()
        }
    }
}

/// Specific manipulation of Realm
public extension Cream {
    
    // MARK: - Insert or Update
    func insertOrUpdate<T: Object>(object: T) throws {
        guard let primaryKey = T.primaryKey() else { fatalError("Can not execute insertOrUpdate when no primaryKey in \(T.description())") }
        guard let primaryKeyValue = object.value(forKey: primaryKey) else { fatalError("Can not find the given primaryKey value of \(T.description())") }
        
        if let _ = realm.object(ofType: T.self, forPrimaryKey: primaryKeyValue) {
            /// Update
            realm.beginWrite()
            realm.add(object, update: true)
            try realm.commitWrite()
        } else {
            /// Insert new
            realm.beginWrite()
            realm.add(object)
            try realm.commitWrite()
        }
    }
    
    // MARK: - Todo: delete
}

