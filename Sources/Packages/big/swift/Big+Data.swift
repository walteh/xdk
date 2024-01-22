//
//  Big+Data.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

//
//  Data Conversion.swift
//  big.Int
//
//  Created by Károly Lőrentey on 2016-01-04.
//  Copyright © 2016-2017 Károly Lőrentey.
//

import Foundation

public extension big.UInt {
	// MARK: NSData Conversion

	/// Initialize a big.Int from bytes accessed from an UnsafeRawBufferPointer
	init(_ buffer: UnsafeRawBufferPointer) {
		// This assumes Word is binary.
		precondition(Word.bitWidth % 8 == 0)

		self.init()

		let length = buffer.count
		guard length > 0 else { return }
		let bytesPerDigit = Word.bitWidth / 8
		var index = length / bytesPerDigit
		var c = bytesPerDigit - length % bytesPerDigit
		if c == bytesPerDigit {
			c = 0
			index -= 1
		}

		var word: Word = 0
		for byte in buffer {
			word <<= 8
			word += Word(byte)
			c += 1
			if c == bytesPerDigit {
				self[index] = word
				index -= 1
				c = 0
				word = 0
			}
		}
		assert(c == 0 && word == 0 && index == -1)
	}

	/// Initializes an integer from the bits stored inside a piece of `Data`.
	/// The data is assumed to be in network (big-endian) byte order.
	init(_ data: Data) {
		// This assumes Word is binary.
		precondition(Word.bitWidth % 8 == 0)

		self.init()

		let length = data.count
		guard length > 0 else { return }
		let bytesPerDigit = Word.bitWidth / 8
		var index = length / bytesPerDigit
		var c = bytesPerDigit - length % bytesPerDigit
		if c == bytesPerDigit {
			c = 0
			index -= 1
		}
		let word: Word = data.withUnsafeBytes { buffPtr in
			var word: Word = 0
			let p = buffPtr.bindMemory(to: UInt8.self)
			for byte in p {
				word <<= 8
				word += Word(byte)
				c += 1
				if c == bytesPerDigit {
					self[index] = word
					index -= 1
					c = 0
					word = 0
				}
			}
			return word
		}
		assert(c == 0 && word == 0 && index == -1)
	}

	func serializeToNil() -> Data? {
		let res = self.serialize()
		return big.UInt(res).isZero ? nil : res
	}

	/// Return a `Data` value that contains the base-256 representation of this integer, in network (big-endian) byte order.
	func serialize() -> Data {
		// This assumes Digit is binary.
		precondition(Word.bitWidth % 8 == 0)

		let byteCount = (self.bitWidth + 7) / 8

		guard byteCount > 0 else { return Data() }

		var data = Data(count: byteCount)
		data.withUnsafeMutableBytes { buffPtr in
			let p = buffPtr.bindMemory(to: UInt8.self)
			var i = byteCount - 1
			for var word in self.words {
				for _ in 0 ..< Word.bitWidth / 8 {
					p[i] = UInt8(word & 0xFF)
					word >>= 8
					if i == 0 {
						assert(word == 0)
						break
					}
					i -= 1
				}
			}
		}
		return data
	}
}

public extension big.Int {
	/// Initialize a big.Int from bytes accessed from an UnsafeRawBufferPointer,
	/// where the first byte indicates sign (0 for positive, 1 for negative)
	init(_ buffer: UnsafeRawBufferPointer) {
		// This assumes Word is binary.
		precondition(Word.bitWidth % 8 == 0)

		self.init()

		let length = buffer.count

		// Serialized data for a big.Int should contain at least 2 bytes: one representing
		// the sign, and another for the non-zero magnitude. Zero is represented by an
		// empty Data struct, and negative zero is not supported.
		guard length > 1, let firstByte = buffer.first else { return }

		// The first byte gives the sign
		// This byte is compared to a bitmask to allow additional functionality to be added
		// to this byte in the future.
		self.sign = firstByte & 0b1 == 0 ? .plus : .minus

		self.magnitude = big.UInt(UnsafeRawBufferPointer(rebasing: buffer.dropFirst(1)))
	}

	/// Initializes an integer from the bits stored inside a piece of `Data`.
	/// The data is assumed to be in network (big-endian) byte order with a first
	/// byte to represent the sign (0 for positive, 1 for negative)
	init(_ data: Data) {
		// This assumes Word is binary.
		// This is the same assumption made when initializing big.UInt from Data
		precondition(Word.bitWidth % 8 == 0)

		self.init()

		// Serialized data for a big.Int should contain at least 2 bytes: one representing
		// the sign, and another for the non-zero magnitude. Zero is represented by an
		// empty Data struct, and negative zero is not supported.
		guard data.count > 1, let firstByte = data.first else { return }

		// The first byte gives the sign
		// This byte is compared to a bitmask to allow additional functionality to be added
		// to this byte in the future.
		self.sign = firstByte & 0b1 == 0 ? .plus : .minus

		// The remaining bytes are read and stored as the magnitude
		self.magnitude = big.UInt(data.dropFirst(1))
	}

	/// Return a `Data` value that contains the base-256 representation of this integer, in network (big-endian) byte order and a prepended byte to indicate the sign (0 for positive, 1 for negative)
	func serialize() -> Data {
		// Create a data object for the magnitude portion of the big.Int
		let magnitudeData = self.magnitude.serialize()

		// Similar to big.UInt, a value of 0 should return an initialized, empty Data struct
		guard !magnitudeData.isEmpty else { return magnitudeData }

		// Create a new Data struct for the signed big.Int value
		var data = Data(capacity: magnitudeData.count + 1)

		// The first byte should be 0 for a positive value, or 1 for a negative value
		// i.e., the sign bit is the LSB
		data.append(self.sign == .plus ? 0 : 1)

		data.append(magnitudeData)
		return data
	}
}
