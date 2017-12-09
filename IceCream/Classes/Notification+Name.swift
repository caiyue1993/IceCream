//
//  Notification+Name.swift
//  IceCream
//
//  Created by 蔡越 on 09/12/2017.
//

import Foundation

/// I believe this should be the best practice for creating custom notifications.
/// https://stackoverflow.com/questions/37899778/how-do-you-create-custom-notifications-in-swift-3

public protocol NotificationName {
    var name: Notification.Name { get }
}

extension RawRepresentable where RawValue == String, Self: NotificationName {
    public var name: Notification.Name {
        get {
            return Notification.Name(self.rawValue)
        }
    }
}
