//
//  RealmHelpers.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 2/7-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import Foundation
import RealmSwift
import IceCream

typealias IceCreamModel = Object & Identifiable & SoftDeletable

protocol Unfreezable {
    /// Return an unfrozen version of the Realm object
    func unfrozen() -> Self?
}
extension Unfreezable where Self: IceCreamModel {
    func unfrozen() -> Self? {
        return Self.all.first(where: { $0.id == self.id })
    }
}

extension SoftDeletable where Self: IceCreamModel {
    mutating func delete() {
        realmWrite { realm in
            self.isDeleted = true
        }
    }
    static var all: Results<Self> {
        let realm = try! Realm()
        return realm.objects(Self.self).filter( "isDeleted == false").sorted(byKeyPath: "name")
    }
    
    static var allDeleted: Results<Self> {
        let realm = try! Realm()
        return realm.objects(Self.self).filter( "isDeleted == true").sorted(byKeyPath: "name")
    }
}



/// Write to realm in existing or new write transaction.
/// - Parameter action: closure with realm related actions
func realmWrite(action: (Realm) -> Void) {
    do {
        let realm = try Realm()
        if realm.isInWriteTransaction {
            action(realm)
        } else {
            try realm.write {
                action(realm)
            }
        }
    } catch let error as NSError {
        print("Error opening default realm: \(error.localizedDescription)")
        print("CHANGES NOT SAVED!!")
        // FIXME: Add errorhandling. What should we do? Right now we just don't write to the DB.
    }
}

extension Object {
    /// Save object to Realm
    func save() {
         realmWrite { realm in
             realm.add( self, update: .all)
         }
     }
}

public protocol SoftDeletable {
    var isDeleted: Bool { get set }
}

// MARK: - A Different approach to support autoupdating Lists in SwiftUI

/// Wrap a Realm.Results or Realm.LinkingObjects in a wrapper that are suitable for use as a SwiftUI @ObservedObject
/// as Realm.Results and Realm.LinkinkObjects are currently not Observable.
class BindableResults<Element>: ObservableObject
    where Element: Identifiable,
          Element: RealmSwift.Object,
          Element: SoftDeletable
    // Inspired by....
    // https://stackoverflow.com/questions/56720441/how-to-display-realm-results-in-swiftui-list
    // https://github.com/shawnynicole/SwiftUI-Realm/blob/master/Shared/RealmViewModel.swift
{

    var results: AnyRealmCollection<Element> // Frozen version for SwiftUI
    private var __results: AnyRealmCollection<Element>  // Live version for change notification
    private var token: NotificationToken!

    init(_ results: Results<Element>) {
        self.__results = AnyRealmCollection(results)
        self.results   = AnyRealmCollection(results).freeze()
        lateInit()
    }

    init(_ results: LinkingObjects<Element>) {
        self.__results = AnyRealmCollection(results)
        self.results   = AnyRealmCollection(results).freeze()
        lateInit()
    }

    /// Update the frozen results from the Live Realm results
    func refresh() {
        self.objectWillChange.send()
        self.results = AnyRealmCollection(self.__results).freeze()
    }
    
    func lateInit() {
        token = __results.observe { [weak self] _ in
            guard let self = self else { return }
            let className = String(describing: Element.self)
            print("Observed change in \(className)")
            self.objectWillChange.send()
            self.results = AnyRealmCollection(self.__results).freeze()
        }
    }

    deinit {
        token.invalidate()
    }

    /// Delete a set of objects in the results collection using soft deletes
    func delete(at offsets: IndexSet)  {
        print("delete( \(offsets.debugDescription) )")
        realmWrite {realm in
            offsets.forEach { (i) in
                let id = results[i].id
                print("deleting element with id: ( \(id) )")
                guard var data = __results.first(where: { $0.id == id }) else { return }
                data.isDeleted  = true
            }
        }
    }
}
