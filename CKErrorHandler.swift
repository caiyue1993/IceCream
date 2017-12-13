//
//  ErrorHandler.swift
//  IceCream
//
//  Created by @randycarney on 12/12/17.
//

import Foundation
import CloudKit

/*
 This struct returns an explicit CKErrorType binned according to the CKErorr.Code,
 updated to the current Apple documentation CloudKit > CKError > CKError.Code (12/12/2017)
 https://developer.apple.com/documentation/cloudkit/ckerror.code
 
 You can implement this class by switching on the handleCKError function and appropriately handling the relevant errors pertaining to the specific CKOperation.
 */

/*
 This is a more detailed implementation of
 EVCloudKitDao: https://github.com/evermeer/EVCloudKitDao
 from github user evermeer: https://github.com/evermeer
 
 The original handleCloudKitErrorAs() func can be found here:
 https://github.com/evermeer/EVCloudKitDao/blob/master/Source/EVCloudKitDao.swift
 
 A more detailed implementation of the EVCloudKitDao would be useful. There are a ton of great features working and the source code is mostly documented.
 http://cocoadocs.org/docsets/EVCloudKitDao/3.1.0/index.html
 */

public struct CKErrorHandler {
    
    // MARK: - Public API
    public enum CKErrorType {
        case success
        case retry(afterSeconds: Double, message: String)
        case chunk
        case recoverableError(reason: CKFailReason, message: String)
        case fail(reason: CKFailReason, message: String)
    }
    
    // I consider the following speciality cases the most likely to be specifically and separately addressed by custom code in the adopting class
    public enum CKFailReason {
        case changeTokenExpired
        case network
        case quotaExceeded
        case partialFailure
        case serverRecordChanged
        case shareRelated
        case unhandledErrorCode
        case unknown
    }
    
    public func handleCKErrorAs(_ error: Error?, retryAttempt: Double = 1) -> CKErrorType {
        
        if error == nil {
            return .success
        }

        guard let error = error as NSError? else {
            let message = "ErrorHandler.Fail - WTF"
            NSLog(message)
            return .fail(reason: .unknown, message: message)
        }
        
        guard let errorCode: CKError.Code = CKError.Code(rawValue: error.code)  else {
            let message = "ErrorHandler.Fail - CKError.Code doesn't exist: \(error.localizedDescription)"
            NSLog(message)
            return .fail(reason: .unhandledErrorCode, message: message)
        }
        
        let message = returnErrorMessage(errorCode)
        
        switch errorCode {
            
        // RETRY
        case .serverResponseLost,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .resultsTruncated:
            // Use an exponential retry delay which maxes out at half an hour.
            var seconds = Double(pow(2, Double(retryAttempt)))
            if seconds > 60*30 {
                seconds = 60*30
            }
            
            // Or if there is a retry delay specified in the error, then use that.
            let userInfo = error.userInfo
            
            if let retry = userInfo[CKErrorRetryAfterKey] as? NSNumber {
                seconds = Double(truncating: retry)
            }
            
            NSLog("CKErrorHandler - \(message). Should retry in \(seconds) seconds.")
            return .retry(afterSeconds: seconds, message: message)
            
        // RECOVERABLE ERROR
        case .networkUnavailable,
             .networkFailure:
            print("CKErrorHandler.recoverableError: \(message)")
            return .recoverableError(reason: .network, message: message)
        case .changeTokenExpired:
            NSLog("CKErrorHandler.recoverableError: \(message)")
            return .recoverableError(reason: .changeTokenExpired, message: message)
        case .serverRecordChanged:
            NSLog("CKErrorHandler.recoverableError: \(message)")
            return .recoverableError(reason: .serverRecordChanged, message: message)
        case .partialFailure: // shouldn't happen since SyncEngine.syncRecordsToCloudKit isAtomic
            if let dictionary = error.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
                NSLog("CKErrorHandler.partialFailure for \(dictionary.count) items; CKPartialErrorsByItemIDKey: \(dictionary)")
            }
            return .recoverableError(reason: .partialFailure, message: message)
            
        // CHUNK: LIMIT EXCEEDED
        case .limitExceeded:
            NSLog("CKErrorHandler.Chunk: \(message)")
            return .chunk
            
            // FAIL
        // unhandled
        case .assetFileModified,
             .assetFileNotFound,
             .badContainer,
             .badDatabase,
             .batchRequestFailed,
             .constraintViolation,
             .invalidArguments,
             .incompatibleVersion,
             .internalError,
             .managedAccountRestricted,
             .missingEntitlement,
             .notAuthenticated,
             .operationCancelled,
             .permissionFailure,
             .serverRejectedRequest,
             .unknownItem,
             .userDeletedZone,
             .zoneNotFound:
            NSLog("CKErrorHandler.Fail: \(message)")
            return .fail(reason: .unknown, message: message)
        // Share related
        case .alreadyShared,
             .participantMayNeedVerification,
             .referenceViolation,
             .tooManyParticipants:
            NSLog("CKErrorHandler.Fail: \(message)")
            return .fail(reason: .shareRelated, message: message)
        // quota exceeded is sort of a special case where the user has to take action before retry
        case .quotaExceeded:
            NSLog("CKErrorHandler.Fail: \(message)")
            return .fail(reason: .quotaExceeded, message: message)
        }
    }
    
    static public func retryOperationIfPossible(retryAfter: Double, block: @escaping () -> ()) {
        
        let delayTime = DispatchTime.now() + retryAfter
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
            block()
        })

    }
    
    private func returnErrorMessage(_ code: CKError.Code) -> String {
        var returnMessage = ""
        
        switch code {
        case .alreadyShared:
            returnMessage = "Already Shared: a record or share cannot be saved because doing so would cause the same hierarchy of records to exist in multiple shares."
        case .assetFileModified:
            returnMessage = "Asset File Modified: the content of the specified asset file was modified while being saved."
        case .assetFileNotFound:
            returnMessage = "Asset File Not Found: the specified asset file is not found."
        case .badContainer:
            returnMessage = "Bad Container: the specified container is unknown or unauthorized."
        case .badDatabase:
            returnMessage = "Bad Database: the operation could not be completed on the given database."
        case .batchRequestFailed:
            returnMessage = "Batch Request Failed: the entire batch was rejected."
        case .changeTokenExpired:
            returnMessage = "Change Token Expired: the previous server change token is too old."
        case .constraintViolation:
            returnMessage = "Constraint Violation: the server rejected the request because of a conflict with a unique field."
        case .incompatibleVersion:
            returnMessage = "Incompatible Version: your app version is older than the oldest version allowed."
        case .internalError:
            returnMessage = "Internal Error: a nonrecoverable error was encountered by CloudKit."
        case .invalidArguments:
            returnMessage = "Invalid Arguments: the specified request contains bad information."
        case .limitExceeded:
            returnMessage = "Limit Exceeded: the request to the server is too large."
        case .managedAccountRestricted:
            returnMessage = "Managed Account Restricted: the request was rejected due to a managed-account restriction."
        case .missingEntitlement:
            returnMessage = "Missing Entitlement: the app is missing a required entitlement."
        case .networkUnavailable:
            returnMessage = "Network Unavailable: the internet connection appears to be offline."
        case .networkFailure:
            returnMessage = "Network Failure: the internet connection appears to be offline."
        case .notAuthenticated:
            returnMessage = "Not Authenticated: to use this app, you must enable iCloud syncing. Go to device Settings, sign in to iCloud, then in the app settings, be sure the iCloud feature is enabled."
        case .operationCancelled:
            returnMessage = "Operation Cancelled: the operation was explicitly canceled."
        case .partialFailure:
            returnMessage = "Partial Failure: some items failed, but the operation succeeded overall."
        case .participantMayNeedVerification:
            returnMessage = "Participant May Need Verification: you are not a member of the share."
        case .permissionFailure:
            returnMessage = "Permission Failure: to use this app, you must enable iCloud syncing. Go to device Settings, sign in to iCloud, then in the app settings, be sure the iCloud feature is enabled."
        case .quotaExceeded:
            returnMessage = "Quota Exceeded: saving would exceed your current iCloud storage quota."
        case .referenceViolation:
            returnMessage = "Reference Violation: the target of a record's parent or share reference was not found."
        case .requestRateLimited:
            returnMessage = "Request Rate Limited: transfers to and from the server are being rate limited at this time."
        case .serverRecordChanged:
            returnMessage = "Server Record Changed: the record was rejected because the version on the server is different."
        case .serverRejectedRequest:
            returnMessage = "Server Rejected Request"
        case .serverResponseLost:
            returnMessage = "Server Response Lost"
        case .serviceUnavailable:
            returnMessage = "Service Unavailable: Please try again."
        case .tooManyParticipants:
            returnMessage = "Too Many Participants: a share cannot be saved because too many participants are attached to the share."
        case .unknownItem:
            returnMessage = "Unknown Item:  the specified record does not exist."
        case .userDeletedZone:
            returnMessage = "User Deleted Zone: the user has deleted this zone from the settings UI."
        case .zoneBusy:
            returnMessage = "Zone Busy: the server is too busy to handle the zone operation."
        case .zoneNotFound:
            returnMessage = "Zone Not Found: the specified record zone does not exist on the server."
        default:
            returnMessage = "Unhandled Error:\nckErrorCode: \(code.rawValue)"
        }
        
        return returnMessage
    }
    
}

extension Array where Element: CKRecord {
    func chunk(by dividingBy: Int) -> [[Element]] {
        let chunkSize = count/dividingBy
        return stride(from: 0, to: count, by: chunkSize).map({ (startIndex) -> [Element] in
            let endIndex = (startIndex.advanced(by: chunkSize) > count) ? count-startIndex : chunkSize
            return Array(self[startIndex..<startIndex.advanced(by: endIndex)])
        })
    }
}
