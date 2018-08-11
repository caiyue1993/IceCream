import CloudKit

struct RemoteChanges<RemoteModel, RemoteModelId> {
    let added: RemoteModel
    let deletedId: RemoteModelId
}

protocol RemoteDataSourcing {
    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void))
}

struct CloudKitRemoteDataSource: RemoteDataSourcing {
    private let errorHandler = ErrorHandler()
    private let database: CKDatabase
    private let zoneIds: [CKRecordZoneID]
    private let zoneIdOptions: () -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions]

    init(database: CKDatabase = CKContainer.default().privateCloudDatabase, zoneIds: [CKRecordZoneID], zoneIdOptions: @escaping () -> [CKRecordZoneID: CKFetchRecordZoneChangesOptions]) {
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
//            guard let syncObject = `self`.syncObjects.first(where: { $0.customZoneID == recordId.zoneID }) else { return }
//            syncObject.delete(recordID: recordId)
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
}
