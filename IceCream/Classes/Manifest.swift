//
//  LogConfig.swift
//  IceCream
//
//  Created by 蔡越 on 30/01/2018.
//

import Foundation

/// This file is for setting some develop configs for IceCream framework.

public class IceCream {
    
    public static let shared = IceCream()
    
    /// There are quite a lot `print`s in the IceCream source files.
    /// If you don't want to see them in your console, just set `enableLogging` property to false.
    /// The default value is true.
    public var enableLogging: Bool = true
    /// Subscription method enables setting a different CloudKit subscription method for all the SyncEngine's you use
    /// There's Apple recommended way and default alternative way
    /// Alternative way didn't work for all cases so if you have problems not receiving silent pushes try Apple subscription method
    public var subscriptionMethod: SubscriptionMethod = .alternative
    
}

public enum SubscriptionMethod {
    case appleSuggested
    case alternative
}

/// If you want to know more,
/// this post would help: https://medium.com/@maxcampolo/swift-conditional-logging-compiler-flags-54692dc86c5f
internal func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if (IceCream.shared.enableLogging) {
        #if DEBUG
        var i = items.startIndex
        repeat {
            Swift.print(items[i], separator: separator, terminator: i == (items.endIndex - 1) ? terminator : separator)
            i += 1
        } while i < items.endIndex
        #endif
    }
}
