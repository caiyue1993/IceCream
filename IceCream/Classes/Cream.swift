import Foundation
import RealmSwift

extension Realm {
    static func purgeDeletedObjects<T: Object & CKRecordConvertible>(ofType: T.Type, withoutNotifying token: NotificationToken? = nil) throws {
        
        let tokens = token != nil ? [token!] : []
        
        do {
            let realm = try Realm()
            let objects = realm.objects(T.self)
            realm.beginWrite()
            realm.delete(objects)
            try realm.commitWrite(withoutNotifying: tokens)
            
        } catch(let error) {
            throw(error)
        }
    }
}
