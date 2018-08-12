import IceCream
import CloudKit
import RealmSwift

class MockObject: Object {
    var registerLocalDatabaseCalled: (() -> Void)? = nil
    var addCalled: ((CKRecord) -> Void)? = nil
    var removeCalled: ((CKRecordID) -> Void)? = nil

    var recordType: String = "Test"

    var customZoneID: CKRecordZoneID = mockRecordZoneId()

    var zoneChangesToken: CKServerChangeToken? = nil

    var isCustomZoneCreated: Bool = true

    func registerLocalDatabase() {
        registerLocalDatabaseCalled?()
    }

    func cleanUp() { }

    func add(record: CKRecord) {
        addCalled?(record)
    }

    func delete(recordID: CKRecordID) {
        removeCalled?(recordID)
    }

    var pipeToEngine: (([CKRecord], [CKRecordID]) -> ())?
}

extension MockObject: Syncable { }

extension MockObject: CKRecordConvertible, CKRecordRecoverable {
    var isDeleted: Bool {
        return false
    }
}
