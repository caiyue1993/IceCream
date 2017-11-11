import Foundation
import RealmSwift

/// Cream is the Alfred of Realm.
/// You do insert/update/delete with Cream instead of manipulating Realm itself.

public final class Cream<T: Object> {
    
    /// The original realm that Cream dances with.
    let realm: Realm
    
    // MARK: - Initializer
    public init(realm: Realm? = nil) {
        if let r = realm {
            self.realm = r
        } else {
            self.realm = try! Realm()
        }
    }
}

/// Specific manipulation of Realm
public extension Cream {
    
}

