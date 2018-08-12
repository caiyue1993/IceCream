import CloudKit

func mockCKRecord() -> CKRecord {
    return CKRecord(recordType: "Test", recordID: mockCKRecordId())
}

func mockCKRecordId() -> CKRecordID {
    return CKRecordID(recordName: "RecordId", zoneID: mockRecordZoneId())
}

func mockRecordZoneId() -> CKRecordZoneID {
    return CKRecordZoneID(zoneName: "Test", ownerName: "Test")
}
