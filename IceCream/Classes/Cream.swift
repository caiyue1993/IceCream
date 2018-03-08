import Foundation
import RealmSwift

extension Realm {
    static func purgeDeletedObjects<T: Object>(ofType: T.Type, withoutNotifying token: NotificationToken? = nil) throws {
        
        let tokens = token != nil ? [token!] : []
        
        do {
            let realm = try Realm()
            let objects = Array(realm.objects(T.self))
                .map { $0 as? Object & CKRecordConvertible }
                .filter { $0 != nil }.map  { $0! }
                .filter { $0.isDeleted }
                .map { $0 as Object }
            
            realm.beginWrite()
            realm.delete(objects)
            try realm.commitWrite(withoutNotifying: tokens)
            
        } catch(let error) {
            throw(error)
        }
    }
}
