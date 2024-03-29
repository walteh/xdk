//
//  Data+Strings.swift
//  nugg.xyz
//
//  Created by walter on 11/18/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

/// Offset between `a` and `A` in ASCII encoding.
public let asciiCasingOffset = Byte.a - Byte.A

public extension Data {
	func utfEncodedString() -> String { String(bytes: self, encoding: .utf8) ?? "" }

	/// Efficiently converts a `Data`'s uppercased ASCII characters to lowercased.
	func lowercasedASCIIString() -> Data {
		var lowercased = Data(repeating: 0, count: self.count)
		var writeIndex = 0

		for i in self.startIndex ..< self.endIndex {
			if self[i] >= .A, self[i] <= .Z {
				lowercased[writeIndex] = self[i] &+ asciiCasingOffset
			} else {
				lowercased[writeIndex] = self[i]
			}

			writeIndex = writeIndex &+ 1
		}

		return lowercased
	}
}

public extension [UInt8] {
	/// Calculates `djb2` hash for this array of `UInt8`.
	var djb2: Int {
		var hash = 5381

		for element in self {
			hash = ((hash << 5) &+ hash) &+ numericCast(element)
		}

		return hash
	}

	/// Efficiently converts an array of bytes uppercased ASCII characters to lowercased.
	func lowercasedASCIIString() -> [UInt8] {
		var lowercased = [UInt8](repeating: 0, count: self.count)
		var writeIndex = 0

		for i in self.startIndex ..< self.endIndex {
			if self[i] >= .A, self[i] <= .Z {
				lowercased[writeIndex] = self[i] &+ asciiCasingOffset
			} else {
				lowercased[writeIndex] = self[i]
			}

			writeIndex = writeIndex &+ 1
		}

		return lowercased
	}

	/// Checks if the current bytes are equal to the contents of the provided `BytesBufferPointer`.
	func caseInsensitiveEquals(to data: BytesBufferPointer) -> Bool {
		guard self.count == data.count else { return false }

		for i in 0 ..< self.count {
			if self[i] & 0xDF != data[i] & 0xDF { return false }
		}

		return true
	}
}

public extension UnsafeBufferPointer where Element == UInt8 {
	/// Checks if the current bytes are equal to the contents of the provided ByteBuffer
	func caseInsensitiveEquals(to data: BytesBufferPointer) -> Bool {
		guard self.count == data.count else { return false }

		for i in 0 ..< self.count {
			if self[i] & 0xDF != data[i] & 0xDF { return false }
		}

		return true
	}
}

// extension Data {
//		/// Reads from a `Data` buffer using a `BytesBufferPointer` rather than a normal pointer
//	public func withByteBuffer<T>(_ closure: (BytesBufferPointer) throws -> T) rethrows -> T {
//		return try self.withUnsafeBytes {pointer in
//			let buffer = BytesBufferPointer(start: pointer,count: self.count)
//
//			return try closure(buffer)
//		}
//	}
//
//		/// Reads from a `Data` buffer using a `MutableBytesBufferPointer` rather than a normal pointer
//	public mutating func withMutableByteBuffer<T>(_ closure: (MutableBytesBufferPointer) throws -> T) rethrows -> T {
//		let count = self.count
//		return try self.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<Byte>) in
//			let buffer = MutableBytesBufferPointer(start: pointer, count: self.count)
//			return try closure(buffer)
//		}
//	}
// }
