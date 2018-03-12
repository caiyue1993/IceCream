//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit
import UserNotifications


extension CKDatabaseScope {
    var string: String {
        switch self {
        case .private:
            return "private"
        case .public:
            return "public"
        case .shared:
            return "shared"
        }
    }
}

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

public final class SyncEngine<SyncedObjectType: Object & CKRecordConvertible> {
    private let syncEngine: ObjectSyncEngine
    
    public init() {
        syncEngine = ObjectSyncEngine(objectType: SyncedObjectType.self, multiObjectSupport: false)
    
        syncEngine.start()
    }
}

public final class ObjectSyncEngine: NotificationTokenStore {
    
//    let subscriptionVersion = "1.1"
    let subscriptionVersion = "2.1"

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
    
    func handleRemoteNotification(userInfo: [AnyHashable : Any]) -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        print("handleRemoteNotification: \(String(describing: notification.subscriptionID))")
        
        if syncedObjects.contains(where: { entry in return entry.value.cloudKitSubscriptionID == notification.subscriptionID}) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
    
            return true
        } else {
            return false
        }
    }
    
    public func handleRemoteNotification() -> Bool {
        
        print("handleRemoteNotification")
        
    //    if syncedObjects.contains(where: { entry in return entry.value.name == recordName}) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: nil)
            
//            return true
//        } else {
//            return false
//        }
        
        return true
    }
    private var objectSyncInfos: [ObjectSyncInfo]
    
    var notificationTokens: [NotificationToken] {
        let notificationTokens = objectSyncInfos
        .map { o ->  NotificationToken? in o.notificationToken }
        .filter { $0 != nil }
        .map { $0! }
        
        return notificationTokens
    }
    
//    private var objectSyncInfo: ObjectSyncInfo {
//        get {
//            return objectSyncInfos.first!
//        }
//        set {
//            objectSyncInfos = [newValue]
//        }
//    }

    private var databaseZones: [DatabaseZone] = []

    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
//    private var notificationTokens: [NotificationToken] = []
    
    private let errorHandler = ErrorHandler()
    
    /// We recommand process the initialization when app launches
    public init(objectType: Object.Type, multiObjectSupport: Bool = true) {
        let zoneName: String
        
        
        if multiObjectSupport {
            zoneName = "IceCream"
        } else {
            zoneName = "\(objectType.className())sZone"
        }
        
        let recordZoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        
        let database = CKContainer.default().privateCloudDatabase
        let databaseZone = DatabaseZone(database: database,
                                        recordZone: CKRecordZone(zoneID: recordZoneID),
                                        multiObjectSupport: false)

        databaseZones.append(databaseZone)
        
        let cloudKitSubscriptionID: String
        
        if multiObjectSupport {
            cloudKitSubscriptionID = "icecream.subscription.\(database.databaseScope.string).\(zoneName).\(objectType.className()).\(subscriptionVersion)"
        } else {
            cloudKitSubscriptionID = "private_changes"
        }
        
        self.objectSyncInfos = [
            ObjectSyncInfo(objectType: objectType,
                            cloudKitSubscriptionID : cloudKitSubscriptionID,
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
        
        for databaseZone in databaseZones {
            databaseZone.notificationTokenStore = self
        }
        
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
                for databaseZone in weakSelf.databaseZones {
                    databaseZone.fetchChangesInDatabase() {
                        print("First sync of \(databaseZone)")
                    }
                }

                weakSelf.resumeLongLivedOperationIfPossible()
                
                for databaseZone in weakSelf.databaseZones {
                    databaseZone.createCustomZone()
                }

                weakSelf.startObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    for objectSyncInfo in weakSelf.objectSyncInfos {
                        objectSyncInfo.registerLocalDatabase(errorHandler: weakSelf.errorHandler)
                    }
                }
                
                NotificationCenter.default.addObserver(weakSelf, selector: #selector(weakSelf.cleanUp), name: .UIApplicationWillTerminate, object: nil)
                
                for objectSyncInfo in weakSelf.objectSyncInfos {
                    objectSyncInfo.createDatabaseSubscription(errorHandler: weakSelf.errorHandler)
                }
            } else {
                /// Handle when user account is not available
                print("Easy, my boy. You haven't logged into iCloud account on your device/simulator yet.")
            }
        }
    }
    
    
    func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name,
                                               object: nil,
                                               queue: OperationQueue.main)
        { (_) in
            for databaseZone in self.databaseZones {
                databaseZone.fetchChangesInDatabase()
            }
        }
    }
    
    @objc func cleanUp() {

        do {
            try objectSyncInfos.forEach {
                try Realm.purgeDeletedObjects(ofType: $0.T, withoutNotifying: self.notificationTokens)
            }
        } catch {
            // Error handles here
        }
    }
}

/// Public Methods
extension ObjectSyncEngine {
    
    // Manually sync data with CloudKit
    public func sync() {

        for databaseZone in databaseZones {
            databaseZone.fetchChangesInDatabase()
        }
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
