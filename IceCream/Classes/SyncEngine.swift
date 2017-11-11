//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

public final class SyncEngine<T: Object & CKRecordConvertible> {
    
    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?
    
    // Indicates the private database in default container
    let privateDatabase = CKContainer.default().privateCloudDatabase
    
    public init() {
        registerLocalDatabase()
    }
    
    
    /// When you commit a write transaction to a Realm, all other instances of that Realm will be notified, and be updated automatically.
    /// For more: https://realm.io/docs/swift/latest/#writes

    private func registerLocalDatabase() {
        let objects = Cream().realm.objects(T.self)
        notificationToken = objects.observe({ [weak self](changes) in
            guard let `self` = self else { return }
            
            switch changes {
            case .initial(let collection):
                print("Inited:" + "\(collection)")
                break
            case .update(let collection, let deletions, let insertions, let modifications):
                print("collections:" + "\(collection)")
                print("deletions:" + "\(deletions)")
                print("insertions:" + "\(insertions)")
                print("modifications:" + "\(modifications)")
                
                let objectsToStore = (insertions + modifications).map { collection[$0] }
                let objectsToDelete = deletions.map { collection[$0] }
                
                `self`.syncObjectsToCloudKit(objectsToStore: objectsToStore, objectsToDelete: objectsToDelete)
                
            case .error(_):
                break
            }
        })
    }
    
    private func syncObjectsToCloudKit(objectsToStore: [T], objectsToDelete: [T]) {
        guard objectsToStore.count > 0 || objectsToDelete.count > 0 else { return }
        
        let recordsToStore = objectsToStore.map{ $0.record }
        let recordIDsToDelete = objectsToDelete.map{ $0.recordID }
        
        syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
    }
    
}

extension SyncEngine {
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    fileprivate func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        modifyOpe.savePolicy = .allKeys
        modifyOpe.modifyRecordsCompletionBlock = { _, _, error in
            guard error == nil else {
                // Handle when error occurs
                return
            }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOpe)
    }
    
}
