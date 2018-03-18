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
    
    public func handleRemoteNotification(userInfo: [AnyHashable : Any]) -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        print("handleRemoteNotification: \(String(describing: notification.subscriptionID))")
        
        if syncedObjects.contains(where: { entry in return entry.value.cloudKitSubscriptionID == notification.subscriptionID}) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
    
            return true
        } else {
            return false
        }
    }
    
    private var objectSyncInfos: [ObjectSyncInfo] = []
    
    var notificationTokens: [NotificationToken] {
        let notificationTokens = objectSyncInfos
        .map { o ->  NotificationToken? in o.notificationToken }
        .filter { $0 != nil }
        .map { $0! }
        
        return notificationTokens
    }

    private var databaseZones: Set<DatabaseZone> = Set<DatabaseZone>()
    private var privateDatabaseZones: [DatabaseZone] {
        return databaseZones.filter { $0.database.databaseScope == .private }
    }
    private var publicDatabaseZones: [DatabaseZone] {
        return databaseZones.filter { $0.database.databaseScope == .public }
    }

    /// Notifications are delivered as long as a reference is held to the returned notification token. You should keep a strong reference to this token on the class registering for updates, as notifications are automatically unregistered when the notification token is deallocated.
    /// For more, reference is here: https://realm.io/docs/swift/latest/#notifications
//    private var notificationTokens: [NotificationToken] = []
    
    private let errorHandler = ErrorHandler()
    
    /// We recommand process the initialization when app launches
    public convenience init(objectType: Object.Type, multiObjectSupport: Bool = true) {
        self.init(privateObjectTypes: [objectType], multiObjectSupport: multiObjectSupport)
    }
    
    public init(privateObjectTypes: [Object.Type] = [], publicObjectTypes: [Object.Type] = [], multiObjectSupport: Bool = true) {
        
        let multiObjectSupport = multiObjectSupport || (privateObjectTypes.count > 1) || (!publicObjectTypes.isEmpty)
    
        let privateObjectSyncInfos = privateObjectTypes.map { objectType -> ObjectSyncInfo in
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
                                            multiObjectSupport: multiObjectSupport)
            
            databaseZones.insert(databaseZone)
            
            let cloudKitSubscriptionID: String
            
            if multiObjectSupport {
                cloudKitSubscriptionID = "icecream.subscription.\(database.databaseScope.string).\(zoneName).\(objectType.className()).\(subscriptionVersion)"
            } else {
                cloudKitSubscriptionID = "private_changes"
            }
            
            let objectSyncInfo = ObjectSyncInfo(objectType: objectType,
                                                cloudKitSubscriptionID : cloudKitSubscriptionID,
                                                databaseZone: databaseZone)
            
            return objectSyncInfo
        }
        
        let publicObjectSyncInfos = publicObjectTypes.map { objectType -> ObjectSyncInfo in
            let zoneName: String
            
            zoneName = "_defaultZone"
            
            let recordZoneID = CKRecordZoneID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
            
            let database = CKContainer.default().publicCloudDatabase
            let databaseZone = DatabaseZone(database: database,
                                            recordZone: CKRecordZone(zoneID: recordZoneID),
                                            multiObjectSupport: true)
            
            databaseZones.insert(databaseZone)
            
            let cloudKitSubscriptionID: String
            
            cloudKitSubscriptionID = "icecream.subscription.\(database.databaseScope.string).\(zoneName).\(objectType.className()).\(subscriptionVersion)"
             
            let objectSyncInfo = ObjectSyncInfo(objectType: objectType,
                                                cloudKitSubscriptionID : cloudKitSubscriptionID,
                                                databaseZone: databaseZone)
            
            return objectSyncInfo
        }

        self.objectSyncInfos = privateObjectSyncInfos + publicObjectSyncInfos
        
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
                for databaseZone in weakSelf.privateDatabaseZones {
                    databaseZone.fetchChangesInDatabase() {
                        print("First sync of \(databaseZone)")
                    }
                }
                
                weakSelf.objectSyncInfos
                    .filter { $0.databaseScope == .public }
                    .forEach { weakSelf.cachePublicRecords(objectTypeName: $0.name) }

                weakSelf.resumeLongLivedOperationIfPossible()
                
                for databaseZone in weakSelf.privateDatabaseZones {
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
        { notification in
            self.cacheRemoteChanges(notification: notification)
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

        for databaseZone in privateDatabaseZones {
            databaseZone.fetchChangesInDatabase()
        }
        
        objectSyncInfos
        .filter { $0.databaseScope == .public }
        .forEach { cachePublicRecords(objectTypeName: $0.name) }
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

extension ObjectSyncEngine {
    func cacheRemoteChanges(notification: Notification) {
        
        guard let userInfo = notification.userInfo else { return }
        
        let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        guard let subscriptionID = cloudKitNotification.subscriptionID else { return }
      
        let databaseScope: Substring
        let objectTypeName: String

        if subscriptionID == "private_changes" {
            print("Hack to maintain support of original example")
            databaseScope = "private"
            objectTypeName = "Dog"
        } else {
            let splits = subscriptionID.split(separator: ".")
            guard splits.count >= 6 else { return }
            
            databaseScope = splits[2]
            objectTypeName = String(splits[4])
        }

        guard let objectSyncInfo = self.syncedObjects[objectTypeName] else { return }

        switch databaseScope {
        case "public":
            cachePublicRecords(objectTypeName: objectTypeName)

        case "private":
            let databaseZone = objectSyncInfo.databaseZone
            databaseZone.fetchChangesInDatabase()
            
        default:
            print("unsupported scope: \(databaseScope)")
        }
    }
    
    func cachePublicRecords(objectTypeName: String) {
        cacheChangedPublicRecords(objectTypeName: objectTypeName)
        purgeDeletedPublicRecords(objectTypeName: objectTypeName)
    }
    
    func cacheChangedPublicRecords(objectTypeName: String) {
        let recordType = objectTypeName
        
        let operation = queryOperation(recordType: recordType)
        operation.recordFetchedBlock = { record in
            self.updateObjectFrom(record: record)
        }
        
        CKContainer.default().publicCloudDatabase.add(operation)
    }
    
    func updateObjectFrom(record: CKRecord) {
        /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
        /// Handle the record:
        guard let objectType = ObjectTypeRegister.entries[record] else { fatalError() }
        guard let object = CloudKitToObject.object(ofType: objectType, withRecord: record) else {
            print("There is something wrong with the conversion from cloud record to local object")
            return
        }
        
        DispatchQueue.main.async {
            let realm = try! Realm()
            
            /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
            /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
            realm.beginWrite()
            realm.add(object, update: true)
            try! realm.commitWrite(withoutNotifying: self.notificationTokens )
        }
    }
    
    func purgeDeletedPublicRecords(objectTypeName: String) {
        let recordType = objectTypeName
        
        guard let T = ObjectTypeRegister.entries[objectTypeName] else { return }
        
        var deletedObjectKeys:[(key: String, value: String)] = []
        var objects: [Object] = []
        
        DispatchQueue.main.async {
            let realm = try! Realm()
            
            objects = Array(realm.objects(T))
        
            deletedObjectKeys = objects
            .map { object -> (key: String, value: String)? in
                guard let primaryKey = self.primaryKey(object: object) else { return nil }
                
                return primaryKey
            }
            .filter { $0 != nil }.map { $0! }

            let operation = self.queryOperation(recordType: recordType)
            
            operation.recordFetchedBlock = { record in
                
            deletedObjectKeys = deletedObjectKeys.filter { (key, value) in
                
                    return value != record.recordID.recordName
                }
            }
            
            operation.queryCompletionBlock = { cursor, error in
                guard error == nil else { return }
        
                DispatchQueue.main.async {
                    let realm = try! Realm()
                    
                    realm.beginWrite()

                    deletedObjectKeys.forEach { (key, value) in
                        let object = realm.objects(T).filter("\(key) = '\(value)'")
                        realm.delete(object)
                    }
                    
                    try! realm.commitWrite(withoutNotifying: self.notificationTokens )
                }
            }
            
            CKContainer.default().publicCloudDatabase.add(operation)
        }
    }
    
    func queryOperation(recordType: String) -> CKQueryOperation {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let queryOperation = CKQueryOperation(query: query)

        return queryOperation
    }
    
    func primaryKey(object: Object) -> (key: String, value: String)? {
        let T = type(of: object)
        
        guard let primaryKey = T.primaryKey() else { return nil }

        let primaryKeyProperty = object.objectSchema.properties.filter {
            $0.name == primaryKey
        }
        
        guard let property = primaryKeyProperty.first else { return nil }

        if let value = object[property.name] as? String {
            return (key: property.name, value: value)
        } else {
            return nil
        }
    }
}
