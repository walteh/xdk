//
//  Big+Bit.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

public extension big.UInt {
	/// Return the ones' complement of `a`.
	///
	/// - Complexity: O(a.count)
	static prefix func ~ (a: big.UInt) -> big.UInt {
		return big.UInt(words: a.words.map { ~$0 })
	}

	/// Calculate the bitwise OR of `a` and `b`, and store the result in `a`.
	///
	/// - Complexity: O(max(a.count, b.count))
	static func |= (a: inout big.UInt, b: big.UInt) {
		a.reserveCapacity(b.count)
		for i in 0 ..< b.count {
			a[i] |= b[i]
		}
	}

	/// Calculate the bitwise AND of `a` and `b` and return the result.
	///
	/// - Complexity: O(max(a.count, b.count))
	static func &= (a: inout big.UInt, b: big.UInt) {
		for i in 0 ..< Swift.max(a.count, b.count) {
			a[i] &= b[i]
		}
	}

	/// Calculate the bitwise XOR of `a` and `b` and return the result.
	///
	/// - Complexity: O(max(a.count, b.count))
	static func ^= (a: inout big.UInt, b: big.UInt) {
		a.reserveCapacity(b.count)
		for i in 0 ..< b.count {
			a[i] ^= b[i]
		}
	}
}

public extension big.Int {
	static prefix func ~ (x: big.Int) -> big.Int {
		switch x.sign {
		case .plus:
			return big.Int(sign: .minus, magnitude: x.magnitude + 1)
		case .minus:
			return big.Int(sign: .plus, magnitude: x.magnitude - 1)
		}
	}

	static func & (lhs: inout big.Int, rhs: big.Int) -> big.Int {
		let left = lhs.words
		let right = rhs.words
		// Note we aren't using left.count/right.count here; we account for the sign bit separately later.
		let count = Swift.max(lhs.magnitude.count, rhs.magnitude.count)
		var words: [UInt] = []
		words.reserveCapacity(count)
		for i in 0 ..< count {
			words.append(left[i] & right[i])
		}
		if lhs.sign == .minus, rhs.sign == .minus {
			words.twosComplement()
			return big.Int(sign: .minus, magnitude: big.UInt(words: words))
		}
		return big.Int(sign: .plus, magnitude: big.UInt(words: words))
	}

	static func | (lhs: inout big.Int, rhs: big.Int) -> big.Int {
		let left = lhs.words
		let right = rhs.words
		// Note we aren't using left.count/right.count here; we account for the sign bit separately later.
		let count = Swift.max(lhs.magnitude.count, rhs.magnitude.count)
		var words: [UInt] = []
		words.reserveCapacity(count)
		for i in 0 ..< count {
			words.append(left[i] | right[i])
		}
		if lhs.sign == .minus || rhs.sign == .minus {
			words.twosComplement()
			return big.Int(sign: .minus, magnitude: big.UInt(words: words))
		}
		return big.Int(sign: .plus, magnitude: big.UInt(words: words))
	}

	static func ^ (lhs: inout big.Int, rhs: big.Int) -> big.Int {
		let left = lhs.words
		let right = rhs.words
		// Note we aren't using left.count/right.count here; we account for the sign bit separately later.
		let count = Swift.max(lhs.magnitude.count, rhs.magnitude.count)
		var words: [UInt] = []
		words.reserveCapacity(count)
		for i in 0 ..< count {
			words.append(left[i] ^ right[i])
		}
		if (lhs.sign == .minus) != (rhs.sign == .minus) {
			words.twosComplement()
			return big.Int(sign: .minus, magnitude: big.UInt(words: words))
		}
		return big.Int(sign: .plus, magnitude: big.UInt(words: words))
	}

	static func &= (lhs: inout big.Int, rhs: big.Int) {
		lhs = lhs & rhs
	}

	static func |= (lhs: inout big.Int, rhs: big.Int) {
		lhs = lhs | rhs
	}

	static func ^= (lhs: inout big.Int, rhs: big.Int) {
		lhs = lhs ^ rhs
	}
}
