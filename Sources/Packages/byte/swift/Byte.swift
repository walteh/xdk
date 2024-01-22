//
//  Byte.swift
//  nugg.xyz
//
//  Created by walter on 11/18/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

/// A `Byte` is an 8-bit unsigned integer.
public typealias Byte = UInt8

/// `Bytes` are a Swift array of 8-bit unsigned integers.
public typealias Bytes = [Byte]

/// `BytesBufferPointer` are a Swift `UnsafeBufferPointer` to 8-bit unsigned integers.
public typealias BytesBufferPointer = UnsafeBufferPointer<Byte>

/// `MutableBytesBufferPointer` are a Swift `UnsafeMutableBufferPointer` to 8-bit unsigned integers.
public typealias MutableBytesBufferPointer = UnsafeMutableBufferPointer<Byte>

/// `BytesPointer` are a Swift `UnsafePointer` to 8-bit unsigned integers.
public typealias BytesPointer = UnsafePointer<Byte>

/// `MutableBytesPointer` are a Swift `UnsafeMutablePointer` to 8-bit unsigned integers.
public typealias MutableBytesPointer = UnsafeMutablePointer<Byte>

/// Implements pattern matching for `Byte` to `Byte?`.
public func ~= (pattern: Byte, value: Byte?) -> Bool {
	return pattern == value
}

public extension Byte {
	/// Returns the `String` representation of this `Byte` (unicode scalar).
	var string: String {
		let unicode = Unicode.Scalar(self)
		let char = Character(unicode)
		return String(char)
	}

	var hex: String {
		return String(format: "0x%02x", arguments: [self])
	}
}
