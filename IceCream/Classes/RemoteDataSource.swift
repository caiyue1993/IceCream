import CloudKit

protocol RemoteDataSourcing {
    func cloudKitAvailable(_ completed: @escaping (Bool) -> Void)
    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void))
    func resumeLongLivedOperationIfPossible()
    func createCustomZones(_ completion: ((Error?) -> ())?)
    func startObservingRemoteChanges(changed: @escaping () -> Void)
    func createDatabaseSubscription()
    func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())?)
}

struct CloudKitRemoteDataSource: RemoteDataSourcing {
    private let errorHandler = ErrorHandler()
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneIds: [CKRecordZoneID]
    private let zoneIdOptions: () -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions]
    private let zonesToCreate: () -> [CKRecordZone]

    init(container: CKContainer = CKContainer.default(), database: CKDatabase = CKContainer.default().privateCloudDatabase, zoneIds: [CKRecordZoneID], zoneIdOptions: @escaping () -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions], zonesToCreate: @escaping () -> [CKRecordZone]) {
        self.container = container
        self.database = database
        self.zoneIds = zoneIds
        self.zoneIdOptions = zoneIdOptions
        self.zonesToCreate = zonesToCreate
    }

    /// The changes token, for more please reference to https://developer.apple.com/videos/play/wwdc2016/231/
    static func getDatabaseChangeToken() -> CKServerChangeToken? {
        /// For the very first time when launching, the token will be nil and the server will be giving everything on the Cloud to client
        /// In other situation just get the unarchive the data object
        guard let tokenData = UserDefaults.standard.object(forKey: IceCreamKey.databaseChangesTokenKey.value) as? Data else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
    }

    static func setDatabaseChangeToken(token: CKServerChangeToken?) {
        guard let token = token else {
            UserDefaults.standard.removeObject(forKey: IceCreamKey.databaseChangesTokenKey.value)
            return
        }
        let data = NSKeyedArchiver.archivedData(withRootObject: token)
        UserDefaults.standard.set(data, forKey: IceCreamKey.databaseChangesTokenKey.value)
    }

    static func deleteDatabaseChangeToken() {
        UserDefaults.standard.removeObject(forKey: IceCreamKey.databaseChangesTokenKey.value)
    }

    /// Cuz we only need to do subscription once succeed
    static func getSubscriptionIsLocallyCached() -> Bool {
        guard let flag = UserDefaults.standard.object(forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value) as? Bool  else { return false }
        return flag
    }

    static func setSubscriptionIsLocallyCached(_ isCached: Bool) {
        UserDefaults.standard.set(isCached, forKey: IceCreamKey.subscriptionIsLocallyCachedKey.value)
    }

    func cloudKitAvailable(_ completed: @escaping (Bool) -> Void) {
        container.accountStatus { (status, error) in
            completed(status == CKAccountStatus.available)
        }
    }

    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void)) {
        self.fetchDatabaseChange(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
        self.resumeLongLivedOperationIfPossible()
        self.createCustomZones(nil)
        self.startObservingRemoteChanges {
            self.fetchChanges(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
        }
    }

    private func fetchDatabaseChange(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void)) {
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: CloudKitRemoteDataSource.getDatabaseChangeToken())

        /// For more, see the source code, it has the detailed explanation
        changesOperation.fetchAllChanges = true

        changesOperation.changeTokenUpdatedBlock = { newToken in
            CloudKitRemoteDataSource.setDatabaseChangeToken(token: newToken)
        }

        /// Cuz we only have one custom zone, so we don't need to store the CKRecordZoneID temporarily
        /*
         changesOperation.recordZoneWithIDChangedBlock = { [weak self] zoneID in
         guard let `self` = self else { return }
         `self`.changedRecordZoneID = zoneID
         }
         */
        changesOperation.fetchDatabaseChangesCompletionBlock = {
            newToken, _, error in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                CloudKitRemoteDataSource.setDatabaseChangeToken(token: newToken)
                // Fetch the changes in zone level
                self.fetchChangesInZones(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChanges(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    CloudKitRemoteDataSource.deleteDatabaseChangeToken()
                    self.fetchChanges(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
                default:
                    return
                }
            default:
                return
            }
        }
        database.add(changesOperation)
    }

    private func fetchChangesInZones(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void)) {
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: zoneIdOptions())
        changesOp.fetchAllChanges = true

        changesOp.recordZoneChangeTokensUpdatedBlock = { zoneId, token, _ in
            recordZoneTokenUpdated(zoneId, token)
        }

        changesOp.recordChangedBlock = { record in
            added(record)
        }

        changesOp.recordWithIDWasDeletedBlock = { recordId, _ in
            removed(recordId)
        }

        changesOp.recordZoneFetchCompletionBlock = { (zoneId ,token, _, _, error) in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                recordZoneTokenUpdated(zoneId, token)
                print("Sync successfully!")
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.fetchChangesInZones(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
                })
            case .recoverableError(let reason, _):
                switch reason {
                case .changeTokenExpired:
                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
                    recordZoneTokenUpdated(zoneId, nil)
                    self.fetchChangesInZones(recordZoneTokenUpdated: recordZoneTokenUpdated, added: added, removed: removed)
                default:
                    return
                }
            default:
                return
            }
        }

        database.add(changesOp)
    }

    /// Create new custom zones
    /// You can(but you shouldn't) invoke this method more times, but the CloudKit is smart and will handle that for you
    func createCustomZones(_ completion: ((Error?) -> ())?) {
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: zonesToCreate(), recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = {(_, _, error) in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.createCustomZones(completion)
                })
            default:
                return
            }
        }

        database.add(modifyOp)
    }

    func startObservingRemoteChanges(changed: @escaping () -> Void) {
        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: OperationQueue.main, using: { _ in
            changed()
        })
    }

    func createDatabaseSubscription() {
        guard !CloudKitRemoteDataSource.getSubscriptionIsLocallyCached() else { return }
        // The direct below is the subscribe way that Apple suggests in CloudKit Best Practices(https://developer.apple.com/videos/play/wwdc2016/231/) , but it doesn't work here in my place.

        let subscription = CKDatabaseSubscription(subscriptionID: IceCreamConstant.cloudKitSubscriptionID)

        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent Push

        subscription.notificationInfo = notificationInfo

        let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        createOp.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            CloudKitRemoteDataSource.setSubscriptionIsLocallyCached(true)
        }
        createOp.qualityOfService = .utility
        database.add(createOp)
    }

    /// Sync local data to CloudKit
    /// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
    func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())?) {
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

        modifyOpe.modifyRecordsCompletionBlock = { (_, _, error) in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)

                    /// Cause we will get a error when there is very empty in the cloudKit dashboard
                    /// which often happen when users first launch your app.
                    /// So, we put the subscription process here when we sure there is a record type in CloudKit.
                    self.createDatabaseSubscription()
                }
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait) {
                    self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            case .chunk:
                /// CloudKit says maximum number of items in a single request is 400.
                /// So I think 300 should be a fine by them.
                let chunkedRecords = recordsToStore.chunkItUp(by: 300)
                for chunk in chunkedRecords {
                    self.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
                }
            default:
                return
            }
        }

        database.add(modifyOpe)
    }

    /// The CloudKit Best Practice is out of date, now use this:
    /// https://developer.apple.com/documentation/cloudkit/ckoperation
    /// Which problem does this func solve? E.g.:
    /// 1.(Offline) You make a local change, involve a operation
    /// 2. App exits or ejected by user
    /// 3. Back to app again
    /// The operation resumes! All works like a magic!
    func resumeLongLivedOperationIfPossible () {
        container.fetchAllLongLivedOperationIDs { ( opeIDs, error) in
            guard error == nil else { return }
            guard let ids = opeIDs else { return }
            for id in ids {
                self.container.fetchLongLivedOperation(withID: id, completionHandler: { (ope, error) in
                    guard error == nil else { return }
                    if let modifyOp = ope as? CKModifyRecordsOperation {
                        modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
                            print("Resume modify records success!")
                        }
                        self.container.add(modifyOp)
                    }
                })
            }
        }
    }
}
