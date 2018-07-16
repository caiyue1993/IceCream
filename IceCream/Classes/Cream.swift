import Foundation
import RealmSwift

/// Cream is the Alfred of Realm.
/// You do insert/update/delete with Cream instead of manipulating Realm itself.

final class Cream<T: Object & CKRecordConvertible> {
    
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
extension Cream {
    func deletePreviousSoftDeleteObjects(notNotifying token: NotificationToken? = nil) throws {
        let objects = realm.objects(T.self).filter { $0.isDeleted }
        
        let tokens: [NotificationToken]
        if let token = token {
            tokens = [token]
        } else {
            tokens = []
        }
        
        realm.beginWrite()
        objects.forEach({ realm.delete($0) })
        try realm.commitWrite(withoutNotifying: tokens)
    }
}

