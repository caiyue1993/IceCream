//
//  LogConfiguration.swift
//  IceCream
//
//  Created by Soledad on 2020/3/15.
//

import Foundation
import os.log

struct LogConfiguration {
    
    private static let subsystem = "me.soledad.icecream"
    
    enum Category {
        static let general = OSLog(subsystem: LogConfiguration.subsystem, category: "general")
    }
}
