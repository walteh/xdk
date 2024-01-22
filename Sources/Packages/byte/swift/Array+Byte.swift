//
//  Array+Uint8.swift
//  nugg.xyz
//
//  Created by walter on 11/23/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension Array {
	@inlinable
	init(reserveCapacity: Int) {
		self = [Element]()
		self.reserveCapacity(reserveCapacity)
	}

	@inlinable
	var slice: ArraySlice<Element> {
		self[self.startIndex ..< self.endIndex]
	}

	@inlinable
	subscript(safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}
}

public extension [Byte] {
	init(hex: String) {
		self.init(reserveCapacity: hex.unicodeScalars.lazy.underestimatedCount)
		var buffer: UInt8?
		var skip = hex.hasPrefix("0x") ? 2 : 0
		for char in hex.unicodeScalars.lazy {
			guard skip == 0 else {
				skip -= 1
				continue
			}
			guard char.value >= 48, char.value <= 102 else {
				removeAll()
				return
			}
			let v: UInt8
			let c: UInt8 = .init(char.value)
			switch c {
			case let c where c <= 57:
				v = c - 48
			case let c where c >= 65 && c <= 70:
				v = c - 55
			case let c where c >= 97:
				v = c - 87
			default:
				removeAll()
				return
			}
			if let b = buffer {
				append(b << 4 | v)
				buffer = nil
			} else {
				buffer = v
			}
		}
		if let b = buffer {
			append(b)
		}
	}

	func toHexString() -> String {
		lazy.reduce(into: "") {
			var s = String($1, radix: 16)
			if s.count == 1 {
				s = "0" + s
			}
			$0 += s
		}
	}
}

public extension [Byte] {
	/// split in chunks with given chunk size
	@available(*, deprecated)
	func chunks(size chunksize: Int) -> [[Element]] {
		var words = [[Element]]()
		words.reserveCapacity(count / chunksize)
		for idx in stride(from: chunksize, through: count, by: chunksize) {
			words.append(Array(self[idx - chunksize ..< idx])) // slow for large table
		}
		let remainder = suffix(count % chunksize)
		if !remainder.isEmpty {
			words.append(Array(remainder))
		}
		return words
	}
}

public extension Data {
	var bytes: [Byte] {
		return [Byte](self)
	}
}

public extension [Byte] {
	var data: Data {
		return Data(self)
	}
}
