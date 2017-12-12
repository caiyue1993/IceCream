//
//  CKErrorHandler.swift
//  IceCream
//
//  Created by Randy Carney on 12/12/17.
//

import Foundation

//
//  ErrorHandling.swift
//  Shopless
//
//  Created by Randy Carney on 10/19/17.
//  Copyright © 2017 randycarney. All rights reserved.
//
//

import Foundation
import CloudKit

/*
 This struct returns an explicit CKErrorType binned according to the CKErorr.Code,
 updated to the current Apple documentation CloudKit > CKError > CKError.Code
 https://developer.apple.com/documentation/cloudkit/ckerror.code
 
 You can implement this class by switching on the handleCKError function and appropriately handling the relevant errors pertaining to the specific CKOperation.
 
 Check SyncEngine for current implementation:
 
 SyncEngine.fetchChangesInDatabase.fetchDatabaseChangesCompletionBlock
 
 SyncEngine.fetchChangesInZone.recordZoneFetchCompletionBlock
 
 SyncEngine.createCustomZone
 
 SyncEngine.createDatabaseSubscription
 
 SyncEngine.syncRecordsToCloudKit
 
 
 */

/*
 This is a more detailed implementation of
 EVCloudKitDao: https://github.com/evermeer/EVCloudKitDao
 from github user evermeer: https://github.com/evermeer
 
 The original handleCloudKitErrorAs() func can be found here:
 https://github.com/evermeer/EVCloudKitDao/blob/master/Source/EVCloudKitDao.swift
 
 A more detailed implementation of the EVCloudKitDao suitable to IceCream would be useful. He has a ton of great features working and the source code is mostly documented.
 http://cocoadocs.org/docsets/EVCloudKitDao/3.1.0/index.html
 */

public struct CKErrorHandler {
    
    // MARK: - Public API
    public enum CKErrorType {
        case success
        case retry(afterSeconds: Double)
        case recoverableError(reason: CKFailReason)
        case chunk
        case fail(reason: CKFailReason)
    }
    
    // I consider the following speciality cases the most likely to be specifically and separately addressed by custom code in the adopting class
    public enum CKFailReason {
        case changeTokenExpired
        case quotaExceeded
        case partialFailure
        case serverRecordChanged
        case shareRelated
        case unhandledErrorCode
        case unknown
    }
    
    public struct ErrorMessageForUser {
        var message: String
        var buttonTitle: String
    }
    
    public func handleCKErrorAs(_ error: Error?, retryAttempt: Double = 1) -> CKErrorType {

        guard let error = error as NSError? else {
            NSLog("CKErrorHandler.Fail - WTF")
            return .fail(reason: .unknown)
        }
        
        guard let errorCode: CKError.Code = CKError.Code(rawValue: error.code)  else {
            NSLog("CKErrorHandler.Fail - CKError.Code doesn't exist: \(error.localizedDescription)")
            return .fail(reason: .unhandledErrorCode)
        }
        
        let message = returnErrorMessage(errorCode)
        
        switch errorCode {
            
        // RETRY
        case .networkUnavailable,
             .networkFailure,
             .serverResponseLost,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .resultsTruncated:
            // Use an exponential retry delay which maxes out at half an hour.
            var seconds = Double(pow(2, Double(retryAttempt)))
            if seconds > 1800 {
                seconds = 1800
            }
            
            // Or if there is a retry delay specified in the error, then use that.
            let userInfo = error.userInfo
            
            if let retry = userInfo[CKErrorRetryAfterKey] as? NSNumber {
                seconds = Double(truncating: retry)
            }
            
            NSLog("CKErrorHandler.retry: Should retry in \(seconds) seconds. \(message)")
            return .retry(afterSeconds: seconds)
            
        // RECOVERABLE ERROR
        case .changeTokenExpired:
            NSLog("CKErrorHandler.recoverableError: \(message)")
            return .recoverableError(reason: .changeTokenExpired)
        case .serverRecordChanged:
            NSLog("CKErrorHandler.recoverableError: \(message)")
            return .recoverableError(reason: .serverRecordChanged)
        case .partialFailure: // shouldn't happen since SyncEngine.syncRecordsToCloudKit isAtomic
            if let dictionary = error.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
                NSLog("CKErrorHandler.partialFailure for \(dictionary.count) items; CKPartialErrorsByItemIDKey: \(dictionary)")
            }
            return .recoverableError(reason: .partialFailure)
            
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
            return .fail(reason: .unknown)
        // Share related
        case .alreadyShared,
             .participantMayNeedVerification,
             .referenceViolation,
             .tooManyParticipants:
            NSLog("CKErrorHandler.Fail: \(message)")
            return .fail(reason: .shareRelated)
        // quota exceeded is sort of a special case where the user has to take action before retry
        case .quotaExceeded:
            NSLog("CKErrorHandler.Fail: \(message)")
            return .fail(reason: .quotaExceeded)
        }
    }
    
    public func retryOperationIfPossible(retryAfter: Double, block: @escaping () -> ()) {
        
        let delayTime = DispatchTime.now() + retryAfter
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
            block()
        })

    }
    
    private func returnErrorMessage(_ code: CKError.Code) -> ErrorMessageForUser {
        
        // in my code I use this to customize a button for displaying the error in the native viewController implementing CKErrorHandler()
        
        var returnMessage = ErrorMessageForUser(message: "", buttonTitle: "Refresh")
        
        switch code {
        case .alreadyShared:
            returnMessage.message = "Already Shared: a record or share cannot be saved because doing so would cause the same hierarchy of records to exist in multiple shares."
        case .assetFileModified:
            returnMessage.message = "Asset File Modified: the content of the specified asset file was modified while being saved."
        case .assetFileNotFound:
            returnMessage.message = "Asset File Not Found: the specified asset file is not found."
        case .badContainer:
            returnMessage.message = "Bad Container: the specified container is unknown or unauthorized."
        case .badDatabase:
            returnMessage.message = "Bad Database: the operation could not be completed on the given database."
        case .batchRequestFailed:
            returnMessage.message = "Batch Request Failed: the entire batch was rejected."
        case .changeTokenExpired:
            returnMessage.message = "Change Token Expired: the previous server change token is too old."
        case .constraintViolation:
            returnMessage.message = "Constraint Violation: the server rejected the request because of a conflict with a unique field."
        case .incompatibleVersion:
            returnMessage.message = "Incompatible Version: your app version is older than the oldest version allowed."
        case .internalError:
            returnMessage.message = "Internal Error: a nonrecoverable error was encountered by CloudKit."
        case .invalidArguments:
            returnMessage.message = "Invalid Arguments: the specified request contains bad information."
        case .limitExceeded:
            returnMessage.message = "Limit Exceeded: the request to the server is too large."
        case .managedAccountRestricted:
            returnMessage.message = "Managed Account Restricted: the request was rejected due to a managed-account restriction."
        case .missingEntitlement:
            returnMessage.message = "Missing Entitlement: the app is missing a required entitlement."
        case .networkUnavailable:
            returnMessage.message = "Network Unavailable: the internet connection appears to be offline."
        case .networkFailure:
            returnMessage.message = "Network Failure: the internet connection appears to be offline."
        case .notAuthenticated:
            returnMessage.message = "Not Authenticated: to use Shopless, you must enable iCloud syncing. Go to device Settings, sign in to iCloud, then in the Shopless settings, be sure the iCloud feature is enabled."
        case .operationCancelled:
            returnMessage.message = "Operation Cancelled: the operation was explicitly canceled."
        case .partialFailure:
            returnMessage.message = "Partial Failure: some items failed, but the operation succeeded overall."
        case .participantMayNeedVerification:
            returnMessage.message = "Participant May Need Verification: you are not a member of the share."
        case .permissionFailure:
            returnMessage.message = "Permission Failure: to use Shopless, you must enable iCloud syncing. Go to device Settings, sign in to iCloud, then in the Shopless settings, be sure the iCloud feature is enabled."
        case .quotaExceeded:
            returnMessage.message = "Quota Exceeded: saving would exceed your current iCloud storage quota."
        case .referenceViolation:
            returnMessage.message = "Reference Violation: the target of a record's parent or share reference was not found."
        case .requestRateLimited:
            returnMessage.message = "Request Rate Limited: transfers to and from the server are being rate limited at this time."
        case .serverRecordChanged:
            returnMessage.message = "Server Record Changed: the record was rejected because the version on the server is different."
        case .serverRejectedRequest:
            returnMessage.message = "Server Rejected Request"
        case .serverResponseLost:
            returnMessage.message = "Server Response Lost"
        case .serviceUnavailable:
            returnMessage.message = "Service Unavailable: Please try again."
        case .tooManyParticipants:
            returnMessage.message = "Too Many Participants: a share cannot be saved because too many participants are attached to the share."
        case .unknownItem:
            returnMessage.message = "Unknown Item:  the specified record does not exist."
        case .userDeletedZone:
            returnMessage.message = "User Deleted Zone: the user has deleted this zone from the settings UI."
        case .zoneBusy:
            returnMessage.message = "Zone Busy: the server is too busy to handle the zone operation."
        case .zoneNotFound:
            returnMessage.message = "Zone Not Found: the specified record zone does not exist on the server."
        default:
            returnMessage.message = "Unhandled Error:\nckErrorCode: \(code.rawValue)"
        }
        
        // append a little message to alert the user to report back to me
        returnMessage.message = returnMessage.message + "\n\nPlease screenshot this and send to the developer"
        
        return returnMessage
    }
    
}
