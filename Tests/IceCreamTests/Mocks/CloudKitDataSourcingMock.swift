import IceCream
import CloudKit

class CloudKitMock: CloudKitDataSourcing {
    var mockAddedRecords: [CKRecord] = []
    var mockRemovedRecordIds: [CKRecordID] = []
    var recordsSentToStore: [CKRecord] = []
    var recordIdsSendToDelete: [CKRecordID] = []
    var fetchChangesCalled: (() -> Void)? = nil

    func cloudKitAvailable(_ completed: @escaping (Bool) -> Void) {
        completed(true)
    }

    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void)) {
        fetchChangesCalled?()
        for record in mockAddedRecords {
            added(record)
        }

        for id in mockRemovedRecordIds {
            removed(id)
        }
    }

    func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())?) {
        recordsSentToStore = recordsToStore
        recordIdsSendToDelete = recordIDsToDelete
    }
}
