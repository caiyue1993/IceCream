//
//  PrivateDatabaseManager.swift
//  IceCream
//
//  Created by caiyue on 2019/4/22.
//

import CloudKit

final class PrivateDatabaseManager: DatabaseManager {
    
    let container: CKContainer
    let database: CKDatabase
    
    let syncObjects: [Syncable]
    
    public init(objects: [Syncable], container: CKContainer) {
        self.syncObjects = objects
        self.container = container
        self.database = container.privateCloudDatabase
    }
    
    func fetchChangesInDatabase(_ callback: (() -> Void)?) {
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true
        
        /// Only update the changeToken when fetch process completes
        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
            guard let self = self else { return }
            self.databaseChangeToken = newToken
        }
        
        /// Cuz we only have one custom zone, so we don't need to store the CKRecordZoneID temporarily
        /*
         changesOperation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
         guard let self = self else { return }
         self.changedRecordZoneID = zoneID
         }
         */
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            [weak self]
            newToken, _, error in
            guard let self = self else { return }
            switch ErrorHandler.shared.resultType(with: error) {
            case .success:
                self.databaseChangeToken = newToken
                // Fetch the changes in zone level
                self.fetchChangesInZones(callback)
            case .retry(let timeToWait, _):
                ErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInDatabase(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    self.databaseChangeToken = nil
                    self.fetchChangesInDatabase(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        database.add(changesOperation)
    }
    
    func createCustomZonesIfAllowed(_ completion: ((Error?) -> ())?) {
        let zonesToCreate = syncObjects.filter { !$0.isCustomZoneCreated }.map { CKRecordZone(zoneID: $0.zoneID) }
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: zonesToCreate, recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            guard let self = self else { return }
            switch ErrorHandler.shared.resultType(with: error) {
            case .success:
                self.syncObjects.forEach { object in
                    object.isCustomZoneCreated = true
                    DispatchQueue.main.async {
                        object.registerLocalDatabase()
                    }
                }
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                ErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.createCustomZonesIfAllowed(completion)
                })
            default:
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }
        
        database.add(modifyOp)
    }
    
    func createDatabaseSubscriptionIfHaveNot() {
        guard !subscriptionIsLocallyCached else { return }
        let subscription = CKDatabaseSubscription(subscriptionID: IceCreamSubscription.cloudKitPrivateDatabaseSubscriptionID.id)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push
        
        subscription.notificationInfo = notificationInfo
        
        let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        createOp.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            self.subscriptionIsLocallyCached = true
        }
        createOp.qualityOfService = .utility
        database.add(createOp)
    }
    
    private func fetchChangesInZones(_ callback: (() -> Void)? = nil) {
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: zoneIdOptions)
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneId, token, _ in
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
            syncObject.zoneChangesToken = token
        }
        
        changesOp.recordChangedBlock = { [weak self] record in
            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
            /// Handle the record:
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.recordType == record.recordType }) else { return }
            syncObject.add(record: record)
        }
        
        changesOp.recordWithIDWasDeletedBlock = { [weak self] recordId, _ in
            guard let self = self else { return }
            guard let syncObject = self.syncObjects.first(where: { $0.zoneID == recordId.zoneID }) else { return }
            syncObject.delete(recordID: recordId)
        }
        
        changesOp.recordZoneFetchCompletionBlock = { [weak self](zoneId ,token, _, _, error) in
            guard let self = self else { return }
            switch ErrorHandler.shared.resultType(with: error) {
            case .success:
                guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
                syncObject.zoneChangesToken = token
                callback?()
                print("Sync successfully: \(zoneId))")
            case .retry(let timeToWait, _):
                ErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInZones(callback)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
                    syncObject.zoneChangesToken = nil
                    self.fetchChangesInZones(callback)
                default:
                    return
                }
            default:
                return
            }
        }
        
        database.add(changesOp)
    }
    
    func startObservingTermination() {
        #if os(iOS) || os(tvOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: UIApplication.willTerminateNotification, object: nil)
        
        #elseif os(macOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: NSApplication.willTerminateNotification, object: nil)
        
        #endif
    }
    
    func registerLocalDatabase() {
        
    }
}

extension PrivateDatabaseManager {
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
    
    var subscriptionIsLocallyCached: Bool {
        get {
            guard let flag = UserDefaults.standard.object(forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value) as? Bool  else { return false }
            return flag
        }
        set {
            UserDefaults.standard.set(newValue, forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value)
        }
    }
    
    private var zoneIds: [CKRecordZone.ID] {
        return syncObjects.map { $0.zoneID }
    }
    
    private var zoneIdOptions: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] {
        return syncObjects.reduce([CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()) { (dict, syncObject) -> [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions] in
            var dict = dict
            let zoneChangesOptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
            zoneChangesOptions.previousServerChangeToken = syncObject.zoneChangesToken
            dict[syncObject.zoneID] = zoneChangesOptions
            return dict
        }
    }
    
    @objc func cleanUp() {
        for syncObject in syncObjects {
            syncObject.cleanUp()
        }
    }
}
