import CloudKit

protocol RemoteDataSourcing {
    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void))
    func resumeLongLivedOperationIfPossible()
    func createCustomZones(zonesToCreate: [CKRecordZone], _ completion: ((Error?) -> ())?)
    func startObservingRemoteChanges(changed: @escaping () -> Void)
}

struct CloudKitRemoteDataSource: RemoteDataSourcing {
    private let errorHandler = ErrorHandler()
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneIds: [CKRecordZoneID]
    private let zoneIdOptions: () -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions]

    init(container: CKContainer = CKContainer.default(), database: CKDatabase = CKContainer.default().privateCloudDatabase, zoneIds: [CKRecordZoneID], zoneIdOptions: @escaping () -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions]) {
        self.container = container
        self.database = database
        self.zoneIds = zoneIds
        self.zoneIdOptions = zoneIdOptions
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

    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void)) {
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
    private func createCustomZones(zonesToCreate: [CKRecordZone], _ completion: ((Error?) -> ())?) {
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: zonesToCreate, recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = {(_, _, error) in
            switch self.errorHandler.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    completion?(nil)
                }
            case .retry(let timeToWait, _):
                self.errorHandler.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.createCustomZones(zonesToCreate: zonesToCreate, completion)
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
