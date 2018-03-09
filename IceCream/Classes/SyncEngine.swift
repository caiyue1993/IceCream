//
//  SyncEngine.swift
//  IceCream
//
//  Created by 蔡越 on 08/11/2017.
//

import Foundation
import RealmSwift
import CloudKit
import Realm

public enum Notifications: String, NotificationName {
    case cloudKitDataDidChangeRemotely
}

public enum IceCreamKey: String {
    /// Tokens
    case databaseChangesTokenKey
    case zoneChangesTokenKey
    
    /// Flags
    case subscriptionIsLocallyCachedKey
    
    public var value: String {
        return "icecream.keys." + rawValue
    }
}

struct ObjectSyncInfo {
    let objectType: Object.Type
    let subscriptionIsLocallyCachedKey: String
    let recordZone: CKRecordZone
    let database: CKDatabase

    /// Dangerous part:
    /// In most cases, you should not change the string value cause it is related to user settings.
    /// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
    /// Or your user will not save the same subscription again. So you got trouble.
    /// The right way is remove old subscription first and then save new subscription.
    let cloudKitSubscriptionID: String
    
    var name: String {
        return objectType.className()
    }
    
    var T: Object.Type {
        return objectType.self
    }
    
    var recordZoneID: CKRecordZoneID {
        return recordZone.zoneID
    }

    var sharedSchema: RLMObjectSchema? {
        return T.sharedSchema()
    }
    
    func recordID(of object: Object & CKRecordConvertible) -> CKRecordID {
        guard let sharedSchema = sharedSchema else {
            fatalError("No schema settled. Go to Realm Community to seek more help.")
        }
        
        guard let primaryKeyProperty = sharedSchema.primaryKeyProperty else {
            fatalError("You should set a primary key on your Realm object")
        }
        
        //        guard let zoneID: CKRecordZoneID = ObjectSyncEngine.zoneID(forRecordType: Self.recordType) else {
        //            fatalError("\(Self.recordType) has not been registered for syncing.")
        //        }
        
        //        if self is StoredInPublicDatabase {
        //            zoneID = CKRecordZone.default().zoneID
        //        } else {
        //            zoneID = NewSyncEngine.customZoneID
        //        }
        
        if let primaryValueString = object[primaryKeyProperty.name] as? String {
            return CKRecordID(recordName: primaryValueString, zoneID: recordZoneID)
        } else if let primaryValueInt = object[primaryKeyProperty.name] as? Int {
            return CKRecordID(recordName: "\(primaryValueInt)", zoneID: recordZoneID)
        } else {
            fatalError("Primary key should be String or Int")
        }
    }
    
    // Simultaneously init CKRecord with zoneID and recordID, thanks to this guy: https://stackoverflow.com/questions/45429133/how-to-initialize-ckrecord-with-both-zoneid-and-recordid
    func cloudKitRecord(from object: Object & CKRecordConvertible) -> CKRecord {
        let recordID = self.recordID(of: object)
        let objectSchema = sharedSchema!
        
        let r = CKRecord(recordType: name, recordID: recordID)
        let properties = objectSchema.properties
        for prop in properties {
            switch prop.type {
            case .int, .string, .bool, .date, .float, .double, .data:
                r[prop.name] = object[prop.name] as? CKRecordValue
            case .object:
                guard let objectName = prop.objectClassName else { break }
                if objectName == CreamAsset.className() {
                    if let creamAsset = object[prop.name] as? CreamAsset {
                        r[prop.name] = creamAsset.asset
                    } else {
                        /// Just a warm hint:
                        /// When we set nil to the property of a CKRecord, that record's property will be hidden in the CloudKit Dashboard
                        r[prop.name] = nil
                    }
                }
            default:
                break
            }
            
        }
        return r
    }
}

/// Dangerous part:
/// In most cases, you should not change the string value cause it is related to user settings.
/// e.g.: the cloudKitSubscriptionID, if you don't want to use "private_changes" and use another string. You should remove the old subsription first.
/// Or your user will not save the same subscription again. So you got trouble.
/// The right way is remove old subscription first and then save new subscription.
//public struct IceCreamConstant {
//    public static let cloudKitSubscriptionID = "private_changes"
//}

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

        if syncedObjects.contains(where: { (_ , object) in return object.cloudKitSubscriptionID == notification.subscriptionID}) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
    
            return true
        } else {
            return false
        }
    }
    
    private let objectSyncInfos: [ObjectSyncInfo]
    
    private var objectSyncInfo: ObjectSyncInfo {
        return objectSyncInfos.first!
    }

    
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
        
        self.objectSyncInfos = [ObjectSyncInfo(objectType: objectType,
                                             subscriptionIsLocallyCachedKey: IceCreamKey.subscriptionIsLocallyCachedKey.value,
                                             recordZone: CKRecordZone(zoneID: recordZoneID),
                                             database: CKContainer.default().privateCloudDatabase,
                                             cloudKitSubscriptionID: "private_changes")]
        

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
                weakSelf.fetchChangesInDatabase({
                    print("First sync done!")
                })
                
                weakSelf.resumeLongLivedOperationIfPossible()
                
                weakSelf.createCustomZone()
                
                weakSelf.startObservingRemoteChanges()
                
                /// 2. Register to local database
                DispatchQueue.main.async {
                    weakSelf.registerLocalDatabase()
                }
                
                NotificationCenter.default.addObserver(weakSelf, selector: #selector(weakSelf.cleanUp), name: .UIApplicationWillTerminate, object: nil)
                
                if weakSelf.subscriptionIsLocallyCached { return }
                weakSelf.createDatabaseSubscription(forType: weakSelf.objectSyncInfo.name)
                
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
                    
                    `self`.syncObjectsToCloudKit(objectsToStore: objectsToStore, objectsToDelete: objectsToDelete)
                    
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
        self.fetchChangesInDatabase()
    }
    
    // This method is commonly used when you want to push your datas to CloudKit manually
    // In most cases, you don't need this
    public func syncObjectsToCloudKit(objectsToStore: [Object & CKRecordConvertible], objectsToDelete: [Object & CKRecordConvertible] = []) {
        guard objectsToStore.count > 0 || objectsToDelete.count > 0 else { return }
        
        let recordsToStore = objectsToStore.map{ self.objectSyncInfo.cloudKitRecord(from: $0) }
        let recordIDsToDelete = objectsToDelete.map{ self.objectSyncInfo.recordID(of: $0) }
        
        self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete) { error in
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
    
    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    var databaseChangeToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.databaseChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.databaseChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.databaseChangesTokenKey.value)
        }
    }
    
    var zoneChangesToken: CKServerChangeToken? {
        get {
            /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
            /// In other situation just get the unarchive the data object
            guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.zoneChangesTokenKey.value) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let n = newValue else {
                UserDefaults.standard.removeObject(forKey: IceCreamKey.zoneChangesTokenKey.value)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: n)
            UserDefaults.standard.set(data, forKey: IceCreamKey.zoneChangesTokenKey.value)
        }
    }
    
    /// Cuz we only need to do subscription once succeed
    var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value)
        }
    }
    
    /*
    var isVeryFirstLaunch: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: IceCreamConstants.isVeryFirstLaunchKey) as? Bool else { return true }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: IceCreamConstants.isVeryFirstLaunchKey)
        }
    }
    */
    
    /// Only update the changeToken when fetch process completes
    func fetchChangesInDatabase(_ callback: (() -> Void)? = nil) {
        
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true
        
        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
            guard let `self` = self else { return }
            self.databaseChangeToken = newToken
        }
        
        /// Cuz we only have one custom zone, so we don't need to store the CKRecordZoneID temporarily
        /*
        changesOperation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
            guard let `self` = self else { return }
            `self`.changedRecordZoneID = zoneID
        }
        */
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            [weak self]
            newToken, _, error in
             guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                `self`.databaseChangeToken = newToken
                // Fetch the changes in zone level
                `self`.fetchChangesInZone(callback)
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    `self`.fetchChangesInDatabase(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    `self`.databaseChangeToken = nil
                    `self`.fetchChangesInDatabase(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        objectSyncInfo.database.add(changesOperation)
    }
    
    private func fetchChangesInZone(_ callback: (() -> Void)? = nil) {
        
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangesToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [objectSyncInfo.recordZoneID], optionsByRecordZoneID: [objectSyncInfo.recordZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.zoneChangesToken = token
        }
        
        changesOp.recordChangedBlock = { [weak self]record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let `self` = self else { return }
            guard let object = CloudKitToObject.object(ofType: self.objectSyncInfo.T, withRecord: record) else {
                print("There is something wrong with the conversion from cloud record to local object")
                return
            }

            DispatchQueue.main.async {
                let realm = try! Realm()

                /// If your model class includes a primary key, you can have Realm intelligently update or add objects based off of their primary key values using Realm().add(_:update:).
                /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
                realm.beginWrite()
                realm.add(object, update: true)
                if let token = `self`.notificationToken {
                    try! realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! realm.commitWrite()
                }
            }
        }
        
        changesOp.recordWithIDWasDeletedBlock = { [weak self]recordId, _ in
            guard let `self` = self else { return }
            
            DispatchQueue.main.async {
                let realm = try! Realm()
                guard let object = realm.object(ofType: self.objectSyncInfo.T, forPrimaryKey: recordId.recordName) else {
                    // Not found in local
                    return
                }
                CreamAsset.deleteCreamAssetFile(with: recordId.recordName)
                realm.beginWrite()
                realm.delete(object)
                if let token = `self`.notificationToken {
                    try! realm.commitWrite(withoutNotifying: [token])
                } else {
                    try! realm.commitWrite()
                }
            }
        }
        
        changesOp.recordZoneFetchCompletionBlock = { [weak self](_,token, _, _, error) in
            guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                `self`.zoneChangesToken = token
                callback?()
                print("Sync successfully!")
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    `self`.fetchChangesInZone(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    `self`.zoneChangesToken = nil
                    `self`.fetchChangesInZone(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        objectSyncInfo.database.add(changesOp)
    }
 
    
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
 
    /// Check if custom zone already exists
  /* fileprivate func checkCustomZoneExists(_ completion: ((Error?) -> ())? = nil) {
        let checkZoneOp = CKFetchRecordZonesOperation(recordZoneIDs: [customZoneID])
        checkZoneOp.fetchRecordZonesCompletionBlock = { dic, error in
            switch self?.errorHandler.resultType(with: error) {
            case .success?:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait)?:
                ErrorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self?.checkCustomZoneExists(completion)
                })
            default:
                return
            }
        }
        privateDatabase.add(checkZoneOp)
    }
*/
    
    fileprivate func createDatabaseSubscription(forType recordType: String) {
        // The direct below is the subscribe way that Apple suggests in CloudKit Best Practices(https://developer.apple.com/videos/play/wwdc2016/231/) , but it doesn't work here in my place.
        /*
        let subscription = CKDatabaseSubscription(subscriptionID: IceCreamConstants.cloudSubscriptionID)

        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
         
        subscription.notificationInfo = notificationInfo

        let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        createOp.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            self.subscriptionIsLocallyCached = true
        }
        createOp.qualityOfService = .utility
        privateDatabase.add(createOp)
         */
        
        /// So I use the @Guilherme Rambo's plan: https://github.com/insidegui/NoteTaker
        let subscription = CKQuerySubscription(recordType: recordType, predicate: NSPredicate(value: true), subscriptionID: objectSyncInfo.cloudKitSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        subscription.notificationInfo = notificationInfo
        
        objectSyncInfo.database.save(subscription) { [weak self](_, error) in
            guard let `self` = self else { return }
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                print("Register remote successfully!")
                `self`.subscriptionIsLocallyCached = true
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    `self`.createDatabaseSubscription(forType: recordType)
                })
            default:
                return
            }
        }
    }
    
    fileprivate func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { [weak self](_) in
            guard let `self` = self else { return }
            `self`.fetchChangesInDatabase()
        })
    }
    
    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    fileprivate func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
        
        if #available(iOS 11.0, *) {
            let config = CKOperationConfiguration()
            config.isLongLived = true
            modifyOpe.configuration = config
        } else {
            // Fallback on earlier versions
            modifyOpe.isLongLived = true
        }
        
        // We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
        // Apple suggests using .ifServerRecordUnchanged save policy
        // For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
        modifyOpe.savePolicy = .changedKeys
        
        // To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
        // If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
        modifyOpe.isAtomic = true
        
        modifyOpe.modifyRecordsCompletionBlock = {
            [weak self]
            (_, _, error) in
            
            guard let `self` = self else { return }
            
            switch `self`.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                    
                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    if `self`.subscriptionIsLocallyCached { return }
                    `self`.createDatabaseSubscription(forType: `self`.objectSyncInfo.name)
                }
            case .retry(let timeToWait, _):
                `self`.errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    `self`.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be a fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    `self`.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }
        
        objectSyncInfo.database.add(modifyOpe)
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
