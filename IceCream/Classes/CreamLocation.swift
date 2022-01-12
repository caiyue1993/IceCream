//
//  File.swift
//  
//
//  Created by Yue Cai on 2022/1/6.
//

import Foundation
import CloudKit
import RealmSwift
import CoreLocation

public class CreamLocation: Object {
    @objc dynamic public var latitude: CLLocationDegrees = 0
    @objc dynamic public var longitude: CLLocationDegrees = 0
    
    convenience public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.init()
        self.latitude = latitude
        self.longitude = longitude
    }
    
    // MARK: - Used in CKRecordConvertible
    
    var location: CLLocation {
        get {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
    }
    
    // MARK: - Used in CKRecordRecoverable
    
    static func make(location: CLLocation) -> CreamLocation {
        return CreamLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}
