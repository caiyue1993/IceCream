//
//  File.swift
//  
//
//  Created by Soledad on 2021/2/7.
//

import Foundation
import RealmSwift

final class PendingRelationshipsWorker<ListElement: Object> {
    
    private let listElementType: ListElement.Type
    
    var realm: Realm?
    var owner: Object?
    
    private var pendingListElementPrimaryKeyValue: [String: Any] = [:]
    
    init(listElementType: ListElement.Type) {
        self.listElementType = listElementType
    }
    
    func addToPendingListElement(propertyName: String, primaryKeyValue: Any) {
        pendingListElementPrimaryKeyValue[propertyName] = primaryKeyValue
    }
    
    func resolvePendingListElements() {
        guard let owner = owner, let realm = realm, pendingListElementPrimaryKeyValue.count > 0 else { return }
        BackgroundWorker.shared.start {
            for (propName, primaryKeyValue) in self.pendingListElementPrimaryKeyValue {
                guard let list = owner.value(forKey: propName) as? List<ListElement> else { return }
                if let existListElementObject = realm.object(ofType: self.listElementType, forPrimaryKey: primaryKeyValue) {
                    try! realm.write {
                        list.append(existListElementObject)
                    }
                    self.pendingListElementPrimaryKeyValue[propName] = nil
                }
            }
        }
    }
    
}
