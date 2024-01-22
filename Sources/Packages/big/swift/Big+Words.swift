//
//  Big+Words.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension [UInt] {
	mutating func twosComplement() {
		var increment = true
		for i in 0 ..< self.count {
			if increment {
				(self[i], increment) = (~self[i]).addingReportingOverflow(1)
			} else {
				self[i] = ~self[i]
			}
		}
	}
}

public extension big.UInt {
	subscript(bitAt index: Int) -> Bool {
		get {
			precondition(index >= 0)
			let (i, j) = index.quotientAndRemainder(dividingBy: Word.bitWidth)
			return self[i] & (1 << j) != 0
		}
		set {
			precondition(index >= 0)
			let (i, j) = index.quotientAndRemainder(dividingBy: Word.bitWidth)
			if newValue {
				self[i] |= 1 << j
			} else {
				self[i] &= ~(1 << j)
			}
		}
	}
}

public extension big.UInt {
	/// The minimum number of bits required to represent this integer in binary.
	///
	/// - Returns: floor(log2(2 * self + 1))
	/// - Complexity: O(1)
	var bitWidth: Int {
		guard count > 0 else { return 0 }
		return count * Word.bitWidth - self[count - 1].leadingZeroBitCount
	}

	/// The number of leading zero bits in the binary representation of this integer in base `2^(Word.bitWidth)`.
	/// This is useful when you need to normalize a `big.UInt` such that the top bit of its most significant word is 1.
	///
	/// - Note: 0 is considered to have zero leading zero bits.
	/// - Returns: A value in `0...(Word.bitWidth - 1)`.
	/// - SeeAlso: width
	/// - Complexity: O(1)
	var leadingZeroBitCount: Int {
		guard count > 0 else { return 0 }
		return self[count - 1].leadingZeroBitCount
	}

	/// The number of trailing zero bits in the binary representation of this integer.
	///
	/// - Note: 0 is considered to have zero trailing zero bits.
	/// - Returns: A value in `0...width`.
	/// - Complexity: O(count)
	var trailingZeroBitCount: Int {
		guard count > 0 else { return 0 }
		let i = self.words.firstIndex { $0 != 0 }!
		return i * Word.bitWidth + self[i].trailingZeroBitCount
	}
}

public extension big.Int {
	var bitWidth: Int {
		guard !magnitude.isZero else { return 0 }
		return magnitude.bitWidth + 1
	}

	var trailingZeroBitCount: Int {
		// Amazingly, this works fine for negative numbers
		return magnitude.trailingZeroBitCount
	}
}

public extension big.UInt {
	struct Words: RandomAccessCollection {
		private let value: big.UInt

		fileprivate init(_ value: big.UInt) { self.value = value }

		public var startIndex: Int { return 0 }
		public var endIndex: Int { return self.value.count }

		public subscript(_ index: Int) -> Word {
			return self.value[index]
		}
	}

	var words: Words { return Words(self) }

	init(words: some Sequence<Word>) {
		let uc = words.underestimatedCount
		if uc > 2 {
			self.init(words: Array(words))
		} else {
			var it = words.makeIterator()
			guard let w0 = it.next() else {
				self.init()
				return
			}
			guard let w1 = it.next() else {
				self.init(word: w0)
				return
			}
			if let w2 = it.next() {
				var words: [UInt] = []
				words.reserveCapacity(Swift.max(3, uc))
				words.append(w0)
				words.append(w1)
				words.append(w2)
				while let word = it.next() {
					words.append(word)
				}
				self.init(words: words)
			} else {
				self.init(low: w0, high: w1)
			}
		}
	}
}

public extension big.Int {
	struct Words: RandomAccessCollection {
		public typealias Indices = CountableRange<Int>

		private let value: big.Int
		private let decrementLimit: Int

		fileprivate init(_ value: big.Int) {
			self.value = value
			switch value.sign {
			case .plus:
				self.decrementLimit = 0
			case .minus:
				assert(!value.magnitude.isZero)
				self.decrementLimit = value.magnitude.words.firstIndex(where: { $0 != 0 })!
			}
		}

		public var count: Int {
			switch self.value.sign {
			case .plus:
				if let high = value.magnitude.words.last, high >> (Word.bitWidth - 1) != 0 {
					return self.value.magnitude.count + 1
				}
				return self.value.magnitude.count
			case .minus:
				let high = self.value.magnitude.words.last!
				if high >> (Word.bitWidth - 1) != 0 {
					return self.value.magnitude.count + 1
				}
				return self.value.magnitude.count
			}
		}

		public var indices: Indices { return 0 ..< self.count }
		public var startIndex: Int { return 0 }
		public var endIndex: Int { return self.count }

		public subscript(_ index: Int) -> UInt {
			// Note that indices above `endIndex` are accepted.
			if self.value.sign == .plus {
				return self.value.magnitude[index]
			}
			if index <= self.decrementLimit {
				return ~(self.value.magnitude[index] &- 1)
			}
			return ~self.value.magnitude[index]
		}
	}

	var words: Words {
		return Words(self)
	}

	init(words: some Sequence<Word>) {
		var words = Array(words)
		if (words.last ?? 0) >> (Word.bitWidth - 1) == 0 {
			self.init(sign: .plus, magnitude: big.UInt(words: words))
		} else {
			words.twosComplement()
			self.init(sign: .minus, magnitude: big.UInt(words: words))
		}
	}
}
