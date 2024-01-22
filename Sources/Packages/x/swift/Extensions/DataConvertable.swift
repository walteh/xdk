//
//  DataConvertable.swift
//  app
//
//  Created by walter on 9/8/22.
//

import Foundation

public protocol DataConvertible {
	init?(data: Data)
	var data: Data { get }
}

public extension DataConvertible where Self: ExpressibleByIntegerLiteral {
	init?(data: Data) {
		var value: Self = 0
		guard data.count == MemoryLayout.size(ofValue: value) else { return nil }
		_ = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
		self = value
	}

	var data: Data {
		withUnsafeBytes(of: self) { Data($0) }
	}
}

extension Int: DataConvertible {}
extension Float: DataConvertible {}
extension Double: DataConvertible {}
