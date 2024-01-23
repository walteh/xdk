//
//  Big+UInt.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

/// An arbitary precision unsigned integer type, also known as a "big integer".
///
/// Operations on big integers never overflow, but they may take a long time to execute.
/// The amount of memory (and address space) available is the only constraint to the magnitude of these numbers.
///
/// This particular big integer type uses base-2^64 digits to represent integers; you can think of it as a wrapper
/// around `Array<UInt64>`. (In fact, `big.UInt` only uses an array if there are more than two digits.)
extension big.UInt: UnsignedInteger {
	/// The type representing a digit in `big.UInt`'s underlying number system.
	public typealias Word = UInt

	/// The storage variants of a `big.UInt`.
	enum Kind {
		/// Value consists of the two specified words (low and high). Either or both words may be zero.
		case inline(Word, Word)
		/// Words are stored in a slice of the storage array.
		case slice(from: Int, to: Int)
		/// Words are stored in the storage array.
		case array
	}

	/// Initializes a new big.UInt with value 0.
	public init() {
		self.kind = .inline(0, 0)
		self.storage = []
	}

	init(word: Word) {
		self.kind = .inline(word, 0)
		self.storage = []
	}

	init(low: Word, high: Word) {
		self.kind = .inline(low, high)
		self.storage = []
	}

	/// Initializes a new big.UInt with the specified digits. The digits are ordered from least to most significant.
	public init(words: [Word]) {
		self.kind = .array
		self.storage = words
		normalize()
	}

	init(words: [Word], from startIndex: Int, to endIndex: Int) {
		self.kind = .slice(from: startIndex, to: endIndex)
		self.storage = words
		normalize()
	}
}

public extension big.UInt {
	static var isSigned: Bool {
		return false
	}

	/// Return true iff this integer is zero.
	///
	/// - Complexity: O(1)
	var isZero: Bool {
		switch self.kind {
		case .inline(0, 0): return true
		case .array: return self.storage.isEmpty
		default:
			return false
		}
	}

	/// Returns `1` if this value is, positive; otherwise, `0`.
	///
	/// - Returns: The sign of this number, expressed as an integer of the same type.
	func signum() -> big.UInt {
		return self.isZero ? 0 : 1
	}
}

extension big.UInt {
	mutating func ensureArray() {
		switch self.kind {
		case let .inline(w0, w1):
			self.kind = .array
			self.storage = w1 != 0 ? [w0, w1]
				: w0 != 0 ? [w0]
				: []
		case let .slice(from: start, to: end):
			self.kind = .array
			self.storage = Array(self.storage[start ..< end])
		case .array:
			break
		}
	}

	var capacity: Int {
		guard case .array = kind else { return 0 }
		return storage.capacity
	}

	mutating func reserveCapacity(_ minimumCapacity: Int) {
		switch self.kind {
		case let .inline(w0, w1):
			self.kind = .array
			self.storage.reserveCapacity(minimumCapacity)
			if w1 != 0 {
				self.storage.append(w0)
				self.storage.append(w1)
			} else if w0 != 0 {
				self.storage.append(w0)
			}
		case let .slice(from: start, to: end):
			self.kind = .array
			var words: [Word] = []
			words.reserveCapacity(Swift.max(end - start, minimumCapacity))
			words.append(contentsOf: self.storage[start ..< end])
			self.storage = words
		case .array:
			self.storage.reserveCapacity(minimumCapacity)
		}
	}

	/// Gets rid of leading zero digits in the digit array and converts slices into inline digits when possible.
	mutating func normalize() {
		switch self.kind {
		case .slice(from: let start, to: var end):
			assert(start >= 0 && end <= self.storage.count && start <= end)
			while start < end, self.storage[end - 1] == 0 {
				end -= 1
			}
			switch end - start {
			case 0:
				self.kind = .inline(0, 0)
				self.storage = []
			case 1:
				self.kind = .inline(self.storage[start], 0)
				self.storage = []
			case 2:
				self.kind = .inline(self.storage[start], self.storage[start + 1])
				self.storage = []
			case self.storage.count:
				assert(start == 0)
				self.kind = .array
			default:
				self.kind = .slice(from: start, to: end)
			}
		case .array where self.storage.last == 0:
			while self.storage.last == 0 {
				self.storage.removeLast()
			}
		default:
			break
		}
	}

	/// Set this integer to 0 without releasing allocated storage capacity (if any).
	mutating func clear() {
		self.load(0)
	}

	/// Set this integer to `value` by copying its digits without releasing allocated storage capacity (if any).
	mutating func load(_ value: big.UInt) {
		switch self.kind {
		case .inline, .slice:
			self = value
		case .array:
			self.storage.removeAll(keepingCapacity: true)
			self.storage.append(contentsOf: value.words)
		}
	}
}

extension big.UInt {
	// MARK: Collection-like members

	/// The number of digits in this integer, excluding leading zero digits.
	var count: Int {
		switch self.kind {
		case let .inline(w0, w1):
			return w1 != 0 ? 2
				: w0 != 0 ? 1
				: 0
		case let .slice(from: start, to: end):
			return end - start
		case .array:
			return self.storage.count
		}
	}

	/// Get or set a digit at a given index.
	///
	/// - Note: Unlike a normal collection, it is OK for the index to be greater than or equal to `endIndex`.
	///   The subscripting getter returns zero for indexes beyond the most significant digit.
	///   Setting these extended digits automatically appends new elements to the underlying digit array.
	/// - Requires: index >= 0
	/// - Complexity: The getter is O(1). The setter is O(1) if the conditions below are true; otherwise it's O(count).
	///    - The integer's storage is not shared with another integer
	///    - The integer wasn't created as a slice of another integer
	///    - `index < count`
	subscript(_ index: Int) -> Word {
		get {
			precondition(index >= 0)
			switch (self.kind, index) {
			case let (.inline(w0, _), 0): return w0
			case let (.inline(_, w1), 1): return w1
			case let (.slice(from: start, to: end), _) where index < end - start:
				return self.storage[start + index]
			case (.array, _) where index < self.storage.count:
				return self.storage[index]
			default:
				return 0
			}
		}
		set(word) {
			precondition(index >= 0)
			switch (self.kind, index) {
			case let (.inline(_, w1), 0):
				kind = .inline(word, w1)
			case let (.inline(w0, _), 1):
				kind = .inline(w0, word)
			case let (.slice(from: start, to: end), _) where index < end - start:
				self.replace(at: index, with: word)
			case (.array, _) where index < self.storage.count:
				self.replace(at: index, with: word)
			default:
				self.extend(at: index, with: word)
			}
		}
	}

	private mutating func replace(at index: Int, with word: Word) {
		self.ensureArray()
		precondition(index < self.storage.count)
		self.storage[index] = word
		if word == 0, index == self.storage.count - 1 {
			self.normalize()
		}
	}

	private mutating func extend(at index: Int, with word: Word) {
		guard word != 0 else { return }
		self.reserveCapacity(index + 1)
		precondition(index >= self.storage.count)
		self.storage.append(contentsOf: repeatElement(0, count: index - self.storage.count))
		self.storage.append(word)
	}

	/// Returns an integer built from the digits of this integer in the given range.
	func extract(_ bounds: Range<Int>) -> big.UInt {
		switch self.kind {
		case let .inline(w0, w1):
			let bounds = bounds.clamped(to: 0 ..< 2)
			if bounds == 0 ..< 2 {
				return big.UInt(low: w0, high: w1)
			} else if bounds == 0 ..< 1 {
				return big.UInt(word: w0)
			} else if bounds == 1 ..< 2 {
				return big.UInt(word: w1)
			} else {
				return big.UInt()
			}
		case let .slice(from: start, to: end):
			let s = Swift.min(end, start + Swift.max(bounds.lowerBound, 0))
			let e = Swift.max(s, bounds.upperBound > end - start ? end : start + bounds.upperBound)
			return big.UInt(words: self.storage, from: s, to: e)
		case .array:
			let b = bounds.clamped(to: self.storage.startIndex ..< self.storage.endIndex)
			return big.UInt(words: self.storage, from: b.lowerBound, to: b.upperBound)
		}
	}

	func extract<Bounds: RangeExpression>(_ bounds: Bounds) -> big.UInt where Bounds.Bound == Int {
		return self.extract(bounds.relative(to: 0 ..< Int.max))
	}
}

extension big.UInt {
	mutating func shr(byWords amount: Int) {
		assert(amount >= 0)
		guard amount > 0 else { return }
		switch self.kind {
		case let .inline(_, w1) where amount == 1:
			self.kind = .inline(w1, 0)
		case .inline:
			self.kind = .inline(0, 0)
		case let .slice(from: start, to: end):
			let s = start + amount
			if s >= end {
				self.kind = .inline(0, 0)
			} else {
				self.kind = .slice(from: s, to: end)
				self.normalize()
			}
		case .array:
			if amount >= self.storage.count {
				self.storage.removeAll(keepingCapacity: true)
			} else {
				self.storage.removeFirst(amount)
			}
		}
	}

	mutating func shl(byWords amount: Int) {
		assert(amount >= 0)
		guard amount > 0 else { return }
		guard !self.isZero else { return }
		switch self.kind {
		case let .inline(w0, 0) where amount == 1:
			self.kind = .inline(0, w0)
		case let .inline(w0, w1):
			let c = (w1 == 0 ? 1 : 2)
			self.storage.reserveCapacity(amount + c)
			self.storage.append(contentsOf: repeatElement(0, count: amount))
			self.storage.append(w0)
			if w1 != 0 {
				self.storage.append(w1)
			}
			self.kind = .array
		case let .slice(from: start, to: end):
			var words: [Word] = []
			words.reserveCapacity(amount + self.count)
			words.append(contentsOf: repeatElement(0, count: amount))
			words.append(contentsOf: self.storage[start ..< end])
			self.storage = words
			self.kind = .array
		case .array:
			self.storage.insert(contentsOf: repeatElement(0, count: amount), at: 0)
		}
	}
}

extension big.UInt {
	// MARK: Low and High

	/// Split this integer into a high-order and a low-order part.
	///
	/// - Requires: count > 1
	/// - Returns: `(low, high)` such that
	///   - `self == low.add(high, shiftedBy: middleIndex)`
	///   - `high.width <= floor(width / 2)`
	///   - `low.width <= ceil(width / 2)`
	/// - Complexity: Typically O(1), but O(count) in the worst case, because high-order zero digits need to be removed after the split.
	var split: (high: big.UInt, low: big.UInt) {
		precondition(self.count > 1)
		let mid = self.middleIndex
		return (self.extract(mid...), self.extract(..<mid))
	}

	/// Index of the digit at the middle of this integer.
	///
	/// - Returns: The index of the digit that is least significant in `self.high`.
	var middleIndex: Int {
		return (self.count + 1) / 2
	}

	/// The low-order half of this big.UInt.
	///
	/// - Returns: `self[0 ..< middleIndex]`
	/// - Requires: count > 1
	var low: big.UInt {
		return self.extract(0 ..< self.middleIndex)
	}

	/// The high-order half of this big.UInt.
	///
	/// - Returns: `self[middleIndex ..< count]`
	/// - Requires: count > 1
	var high: big.UInt {
		return self.extract(self.middleIndex ..< self.count)
	}
}
