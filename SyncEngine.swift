//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift

public final class SyncEngine {
    
    let objectType: Object
    
    private func subscribeToLocalDatabase() {
        let dogs = Cream.shared.realm.objects(<#T##type: Element.Type##Element.Type#>)
    }
}
