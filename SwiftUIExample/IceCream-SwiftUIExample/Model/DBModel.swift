//
//  DBModel.swift
//  IceCream-SwiftUIExample
//
//  Created by Bo Frese on 2/7-20.
//  Copyright © 2020 i-con.dk. All rights reserved.
//

import Foundation
import RealmSwift
import IceCream

class DBModel {
    // All Realm Object to syncronize vie ClokdKit / IceCream
    public static var syncEngine: SyncEngine {
        SyncEngine(objects: [
            SyncObject<Person>(),
            SyncObject<Cat>()
        ])
    }
    
    static func migration() {
          print("DBModel.migration().......")
          let config = Realm.Configuration(
              // Set the new schema version. This must be greater than the previously used
              // version (if you've never set a schema version before, the version is 0).
              schemaVersion: 1,

              // Set the block which will be called automatically when opening a Realm with
              // a schema version lower than the one set above
              migrationBlock: { migration, oldSchemaVersion in
                  // We haven’t migrated anything yet, so oldSchemaVersion == 0
                  if (oldSchemaVersion < 1) {
                      // Nothing to do!
                      // Realm will automatically detect new properties and removed properties
                      // And will update the schema on disk automatically
                  }
                  /*
                  if (oldSchemaVersion < 2) {
                      migration.enumerateObjects(ofType: SomeRealmObjectClass.className()) { oldObject, newObject in
                          if oldObject!["some_property"] as! SomeType {
                              newObject!["some_other_property"] = some_value
                          }
                      }
                  }
                  */
          })

          // Tell Realm to use this new configuration object for the default Realm
          Realm.Configuration.defaultConfiguration = config

          // Now that we've told Realm how to handle the schema change, opening the file
          // will automatically perform the migration
          let _ = try! Realm()
      }
    
}

