//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift

public final class SyncEngine<T: Object> {
    
    private var notificationToken: NotificationToken?
    
    public init() {
        registerLocalDatabase()
    }
    
    private func registerLocalDatabase() {
        let objects = Cream().realm.objects(T.self)
        notificationToken = objects.observe({ (changes) in
            switch changes {
            case .initial(let collection):
                print("Inited:" + "\(collection)")
                break
            case .update(let collection, let deletions, let insertions, let modifications):
                print("collections:" + "\(collection)")
                print("deletions:" + "\(deletions)")
                print("insertions:" + "\(insertions)")
                print("modifications:" + "\(modifications)")
            case .error(_):
                break
            }
        })
    }
    
}
