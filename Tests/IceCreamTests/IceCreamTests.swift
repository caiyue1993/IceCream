//
//  IceCreamTests.swift
//  IceCreamTests
//
//  Created by David Collado on 8/8/18.
//

import XCTest
import IceCream
import CloudKit
import RealmSwift
@testable import IceCreamTests

class IceCreamTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSetupsSyncObjectCloudPipe() {
        let expectation = XCTestExpectation(description: "Wait cloudkit")
        let syncObject = SyncObject<MockObject>()
        let syncEngine = SyncEngine.start(objects: [syncObject], remoteDataSource: CloudKitMock())
        XCTAssertNotNil(syncObject.pipeToEngine)
    }
}

class MockObject: Object {
    var recordType: String = "Test"

    var customZoneID: CKRecordZoneID = CKRecordZoneID(zoneName: "Test", ownerName: "Test")

    var zoneChangesToken: CKServerChangeToken? = nil

    var isCustomZoneCreated: Bool = true

    func registerLocalDatabase() { }

    func cleanUp() { }

    func add(record: CKRecord) { }

    func delete(recordID: CKRecordID) { }

    var pipeToEngine: (([CKRecord], [CKRecordID]) -> ())?
}

extension MockObject: Syncable { }

extension MockObject: CKRecordConvertible, CKRecordRecoverable {
    var isDeleted: Bool {
        return false
    }
}

class CloudKitMock: CloudKitDataSourcing {
    var recordsSentToStore: [CKRecord] = []
    var recordIdsSendToDelete: [CKRecordID] = []

    func cloudKitAvailable(_ completed: @escaping (Bool) -> Void) {
        completed(true)
    }

    func fetchChanges(recordZoneTokenUpdated: @escaping (CKRecordZoneID, CKServerChangeToken?) -> Void, added: @escaping ((CKRecord) -> Void), removed: @escaping ((CKRecordID) -> Void)) { }

    func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())?) {
        recordsSentToStore = recordsToStore
        recordIdsSendToDelete = recordIDsToDelete
    }
}
