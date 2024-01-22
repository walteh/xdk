//
//  Big+Codable.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

// Little-endian to big-endian
struct Units<Unit: FixedWidthInteger, Words: RandomAccessCollection>: RandomAccessCollection
	where Words.Element: FixedWidthInteger, Words.Index == Int
{
	typealias Word = Words.Element
	let words: Words
	init(of _: Unit.Type, _ words: Words) {
		precondition(Word.bitWidth % Unit.bitWidth == 0 || Unit.bitWidth % Word.bitWidth == 0)
		self.words = words
	}

	var count: Int { return (self.words.count * Word.bitWidth + Unit.bitWidth - 1) / Unit.bitWidth }
	var startIndex: Int { return 0 }
	var endIndex: Int { return self.count }
	subscript(_ index: Int) -> Unit {
		let index = self.count - 1 - index
		if Unit.bitWidth == Word.bitWidth {
			return Unit(self.words[index])
		} else if Unit.bitWidth > Word.bitWidth {
			let c = Unit.bitWidth / Word.bitWidth
			var unit: Unit = 0
			var j = 0
			for i in (c * index) ..< Swift.min(c * (index + 1), self.words.endIndex) {
				unit |= Unit(self.words[i]) << j
				j += Word.bitWidth
			}
			return unit
		}
		// Unit.bitWidth < Word.bitWidth
		let c = Word.bitWidth / Unit.bitWidth
		let i = index / c
		let j = index % c
		return Unit(truncatingIfNeeded: self.words[i] >> (j * Unit.bitWidth))
	}
}

extension Array where Element: FixedWidthInteger {
	// Big-endian to little-endian
	init<Unit: FixedWidthInteger>(count: Int?, generator: () throws -> Unit?) rethrows {
		typealias Word = Element
		precondition(Word.bitWidth % Unit.bitWidth == 0 || Unit.bitWidth % Word.bitWidth == 0)
		self = []
		if Unit.bitWidth == Word.bitWidth {
			if let count {
				self.reserveCapacity(count)
			}
			while let unit = try generator() {
				self.append(Word(unit))
			}
		} else if Unit.bitWidth > Word.bitWidth {
			let wordsPerUnit = Unit.bitWidth / Word.bitWidth
			if let count {
				self.reserveCapacity(count * wordsPerUnit)
			}
			while let unit = try generator() {
				var shift = Unit.bitWidth - Word.bitWidth
				while shift >= 0 {
					self.append(Word(truncatingIfNeeded: unit >> shift))
					shift -= Word.bitWidth
				}
			}
		} else {
			let unitsPerWord = Word.bitWidth / Unit.bitWidth
			if let count {
				self.reserveCapacity((count + unitsPerWord - 1) / unitsPerWord)
			}
			var word: Word = 0
			var c = 0
			while let unit = try generator() {
				word <<= Unit.bitWidth
				word |= Word(unit)
				c += Unit.bitWidth
				if c == Word.bitWidth {
					self.append(word)
					word = 0
					c = 0
				}
			}
			if c > 0 {
				self.append(word << c)
				var shifted: Word = 0
				for i in self.indices {
					let word = self[i]
					self[i] = shifted | (word >> c)
					shifted = word << (Word.bitWidth - c)
				}
			}
		}
		self.reverse()
	}
}

extension big.Int: Codable {
	public init(from decoder: Decoder) throws {
		var container = try decoder.unkeyedContainer()

		// Decode sign
		let sign: big.Int.Sign
		switch try container.decode(String.self) {
		case "+":
			sign = .plus
		case "-":
			sign = .minus
		default:
			throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath,
			                                        debugDescription: "Invalid big integer sign"))
		}

		// Decode magnitude
		let words = try [UInt](count: container.count?.advanced(by: -1)) { () -> UInt64? in
			guard !container.isAtEnd else { return nil }
			return try container.decode(UInt64.self)
		}
		let magnitude = big.UInt(words: words)

		self.init(sign: sign, magnitude: magnitude)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.unkeyedContainer()
		try container.encode(sign == .plus ? "+" : "-")
		let units = Units(of: UInt64.self, self.magnitude.words)
		if units.isEmpty {
			try container.encode(0 as UInt64)
		} else {
			try container.encode(contentsOf: units)
		}
	}
}

extension big.UInt: Codable {
	public init(from decoder: Decoder) throws {
		let value = try big.Int(from: decoder)
		guard value.sign == .plus else {
			throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
			                                        debugDescription: "big.UInt cannot hold a negative value"))
		}
		self = value.magnitude
	}

	public func encode(to encoder: Encoder) throws {
		try big.Int(sign: .plus, magnitude: self).encode(to: encoder)
	}
}
