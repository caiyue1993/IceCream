//
//  CKRecordConnectable.swift
//  IceCream
//
//  Created by Sean Cheng on 8/7/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import Foundation
import RealmSwift

public protocol CKRecordConnectable
{
	static var references: [Object.Type]? { get }
}

extension CKRecordConnectable where Self: Object
{
	public static var references: [Object.Type]? { return nil }
}
