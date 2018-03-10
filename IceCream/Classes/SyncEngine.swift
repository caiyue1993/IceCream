//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

public final class SyncEngine<SyncedObjectType: Object & CKRecordConvertible> {
    private let syncEngine: ObjectSyncEngine
    
    public init(usePublicDatabase: Bool = false) {
        
        syncEngine = ObjectSyncEngine(objectType: SyncedObjectType.self)
    
        syncEngine.start()
    }
}

public final class ObjectSyncEngine {
    
    private lazy var syncedObjects: [String : ObjectSyncInfo] = {
        var syncedObjects = [String: ObjectSyncInfo]()
        self.objectSyncInfos.forEach {
            syncedObjects[$0.name] = $0
        }
        
        return syncedObjects
    }()
    
    public func zoneID(forRecordType recordType: String) -> CKRecordZoneID? {
        let zoneID = syncedObjects[recordType]?.recordZoneID
        
        return zoneID
    }
    
    public func handleRemoteNotification(userInfo: [AnyHashable : Any]) -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        if syncedObjects.contains(where: { entry in return entry.value.cloudKitSubscriptionID == notification.subscriptionID}) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
    
            return true
        } else {
            return false
        }
    }
    
    private var objectSyncInfos: [ObjectSyncInfo]
    
    private var objectSyncInfo: ObjectSyncInfo {
        get {
            return objectSyncInfos.first!
        }
        set {
            objectSyncInfos = [newValue]
        }
    }

    private var databaseZones = Set<DatabaseZone>()
    
//    public static var customZoneID: CKRecordZoneID = CKRecordZoneID(zoneName: "IceCream", ownerName: CKCurrentUserDefaultName)

    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
    private var notificationToken: NotificationToken?
    
//    fileprivate var changedRecordZoneID: CKRecordZoneID?
    
    private let errorHandler = ErrorHandler()
    
    /// We recommand process the initialization when app launches
    public init(objectType: Object.Type) {
        let zoneName = "\(objectType.className())sZone"
        let recordZoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        
        let databaseZone = DatabaseZone(database: CKContainer.default().privateCloudDatabase,
                                        recordZone: CKRecordZone(zoneID: recordZoneID), multiObjectSupport: false)
        
        databaseZones.insert(databaseZone)
        
        self.objectSyncInfos = [
            ObjectSyncInfo(objectType: objectType,
                            subscriptionIsLocallyCachedKey: "icecream.keys.subscriptionIsLocallyCachedKey",
                            cloudKitSubscriptionID : "private_changes",
                            databaseZone: databaseZone)
        ]

//        if usePublicDatabase {
//            database = CKContainer.default().publicCloudDatabase
//            recordZone = CKRecordZone.default()
//        } else {
//            database = CKContainer.default().privateCloudDatabase
//            recordZone = CKRecordZone(zoneID: NewSyncEngine.customZoneID)
//
//
//
//        }
        print("Remember to start() the engine!")
    }
    
    public func start() {
        print("Object Sync Engine started.")
        
        /// Check iCloud status so that we can go on
        CKContainer.default().accountStatus { [weak self] (status, error) in
            if status == CKAccountStatus.available {
                guard let weakSelf = self else {
                    print("weak self == nil")
                    return
                }
                
                /// 1. Fetch changes in the Cloud
                /// Apple suggests that we should fetch changes in database, *especially* the very first launch.
                /// But actually, there **might** be some rare unknown and weird reason that the data is not synced between muilty devices.
                /// So I suggests fetch changes in database everytime app launches.
                weakSelf.objectSyncInfo.databaseZone.fetchChangesInDatabase(notificationToken: weakSelf.notificationToken) {
                    print("First sync done!")
                }
//                weakSelf.fetchChangesInDatabase() {
//                    print("First sync done!")
//                }

                weakSelf.resumeLongLivedOperationIfPossible()
                
                weakSelf.createCustomZone()
                
                weakSelf.startObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    weakSelf.registerLocalDatabase()
                }
                
                NotificationCenter.default.addObserver(weakSelf, selector: #selector(weakSelf.cleanUp), name: .UIApplicationWillTerminate, object: nil)
                
                if  weakSelf.objectSyncInfo.subscriptionIsLocallyCached { return }
                weakSelf.objectSyncInfo.createDatabaseSubscription(errorHandler: weakSelf.errorHandler)
                
//                if weakSelf.subscriptionIsLocallyCached { return }
//                weakSelf.createDatabaseSubscription(forType: weakSelf.objectSyncInfo.name)
                
            } else {
                /// Handle when user account is not available
                print("Easy, my boy. You haven't logged into iCloud account on your device/simulator yet.")
            }
        }
    }
    
    /// When you commit a write transaction to a Realm, all other instances of that Realm will be notified, and be updated automatically.
    /// For more: https://realm.io/docs/swift/latest/#writes

    private func registerLocalDatabase() {
        Realm.query { realm in
            let objects = realm.objects(objectSyncInfo.T)
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
                    
                    let objectsToStore = (insertions + modifications)
                        .filter { $0 < collection.count }
                        .map { i -> (Object & CKRecordConvertible)? in return collection[i] as? Object & CKRecordConvertible }
                        .filter { $0 != nil }.map { $0! }
                        .filter{ !$0.isDeleted }
                    
                    let objectsToDelete = modifications
                        .filter { $0 < collection.count }
                        .map { i -> (Object & CKRecordConvertible)? in return collection[i] as? Object & CKRecordConvertible }
                        .filter { $0 != nil }.map { $0! }
                        .filter { $0.isDeleted }
                    
                    `self`.syncObjectsToCloudKit(objectSyncInfo: &self.objectSyncInfo, objectsToStore: objectsToStore, objectsToDelete: objectsToDelete)
                    
                case .error(_):
                    break
                }
            })
        }
    }
    
    @objc func cleanUp() {
        do {
            try Realm.purgeDeletedObjects(ofType: objectSyncInfo.T, withoutNotifying: notificationToken)
        } catch {
            // Error handles here
        }
    }
}

/// Public Methods
extension ObjectSyncEngine {
    
    // Manually sync data with CloudKit
    public func sync() {
        self.objectSyncInfo.databaseZone.fetchChangesInDatabase(notificationToken: notificationToken)
//        self.fetchChangesInDatabase(for: self.objectSyncInfo)
    }
    
    // This method is commonly used when you want to push your datas to CloudKit manually
    // In most cases, you don't need this
    public func syncObjectsToCloudKit(objectSyncInfo: inout ObjectSyncInfo, objectsToStore: [Object & CKRecordConvertible], objectsToDelete: [Object & CKRecordConvertible] = []) {
        guard objectsToStore.count > 0 || objectsToDelete.count > 0 else { return }
        
        let recordsToStore = objectsToStore.map{ self.objectSyncInfo.cloudKitRecord(from: $0) }
        let recordIDsToDelete = objectsToDelete.map{ self.objectSyncInfo.recordID(of: $0) }
        
        objectSyncInfo.syncRecordsToCloudKit(errorHandler: errorHandler, recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete) { error in
            guard error == nil else { return }
            guard !objectsToDelete.isEmpty else { return }
            
            let realm = try! Realm()
            try! realm.write {
                realm.delete(objectsToDelete as [Object])
            }
            
            print("Completeed deletion of \(objectsToDelete.count) objects")
        }
    }
}

/// Chat to the CloudKit API directly
extension ObjectSyncEngine {
    

    
    
    /// Create new custom zones
    /// You can(but you shouldn't) invoke this method more times, but the CloudKit is smart and will handle that for you
    fileprivate func createCustomZone(_ completion: ((Error?) -> ())? = nil) {
        let newCustomZone = CKRecordZone(zoneID: objectSyncInfo.recordZoneID)
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: [newCustomZone], recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                     `self`.createCustomZone(completion)
                })
            default:
                return
            }
        }
        
        objectSyncInfo.database.add(modifyOp)
    }
        
    fileprivate func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let `self` = self else { return }
            `self`.objectSyncInfo.databaseZone.fetchChangesInDatabase(notificationToken: self.notificationToken)
//            `self`.fetchChangesInDatabase()
        })
    }
    
}

/// Long-lived Manipulation
extension ObjectSyncEngine {
    /// The CloudKit Best Practice is out of date, now use this:
    /// https://developer.apple.com/documentation/cloudkit/ckoperation
    /// Which problem does this func solve? E.g.:
    /// 1.(Offline) You make a local change, involve a operation
    /// 2. App exits or ejected by user
    /// 3. Back to app again
    /// The operation resumes! All works like a magic!
    fileprivate func resumeLongLivedOperationIfPossible () {
        CKContainer.default().fetchAllLongLivedOperationIDs { ( opeIDs, error) in
            guard error == nil else { return }
            guard let ids = opeIDs else { return }
            for id in ids {
                CKContainer.default().fetchLongLivedOperation(withID: id, completionHandler: { (ope, error) in
                    guard error == nil else { return }
                    if let modifyOp = ope as? CKModifyRecordsOperation {
                        modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
                            print("Resume modify records success!")
                        }
                        CKContainer.default().add(modifyOp)
                    }
                })
            }
        }
    }
}
