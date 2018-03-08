//
//  RealmExtension.swift
//  IceCream
//
//  Created by Andrew Eades on 11/11/2017..
//

import Foundation
import RealmSwift

extension Realm {
    static private var main: Realm {
        get {
            let realm = try! Realm()
            return realm
        }
    }
    
    static func transaction(_ block: (Realm) -> Void) {
        let realm = Realm.main
        do {
            try realm.write {
                block(realm)
            }
        } catch(let error) {
            print("transaction block error: \(error)")
        }
    }
    
    static func query(_ block: (Realm) -> Void) {
        let realm = Realm.main
        block(realm)
    }

}
