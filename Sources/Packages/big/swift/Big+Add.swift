//
//  Big+Add.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension big.UInt {
	// MARK: Addition

	/// Add `word` to this integer in place.
	/// `word` is shifted `shift` words to the left before being added.
	///
	/// - Complexity: O(max(count, shift))
	internal mutating func addWord(_ word: Word, shiftedBy shift: Int = 0) {
		precondition(shift >= 0)
		var carry = word
		var i = shift
		while carry > 0 {
			let (d, c) = self[i].addingReportingOverflow(carry)
			self[i] = d
			carry = (c ? 1 : 0)
			i += 1
		}
	}

	/// Add the digit `d` to this integer and return the result.
	/// `d` is shifted `shift` words to the left before being added.
	///
	/// - Complexity: O(max(count, shift))
	internal func addingWord(_ word: Word, shiftedBy shift: Int = 0) -> big.UInt {
		var r = self
		r.addWord(word, shiftedBy: shift)
		return r
	}

	/// Add `b` to this integer in place.
	/// `b` is shifted `shift` words to the left before being added.
	///
	/// - Complexity: O(max(count, b.count + shift))
	internal mutating func add(_ b: big.UInt, shiftedBy shift: Int = 0) {
		precondition(shift >= 0)
		var carry = false
		var bi = 0
		let bc = b.count
		while bi < bc || carry {
			let ai = shift + bi
			let (d, c) = self[ai].addingReportingOverflow(b[bi])
			if carry {
				let (d2, c2) = d.addingReportingOverflow(1)
				self[ai] = d2
				carry = c || c2
			} else {
				self[ai] = d
				carry = c
			}
			bi += 1
		}
	}

	/// Add `b` to this integer and return the result.
	/// `b` is shifted `shift` words to the left before being added.
	///
	/// - Complexity: O(max(count, b.count + shift))
	internal func adding(_ b: big.UInt, shiftedBy shift: Int = 0) -> big.UInt {
		var r = self
		r.add(b, shiftedBy: shift)
		return r
	}

	/// Increment this integer by one. If `shift` is non-zero, it selects
	/// the word that is to be incremented.
	///
	/// - Complexity: O(count + shift)
	internal mutating func increment(shiftedBy shift: Int = 0) {
		self.addWord(1, shiftedBy: shift)
	}

	/// Add `a` and `b` together and return the result.
	///
	/// - Complexity: O(max(a.count, b.count))
	public static func + (a: big.UInt, b: big.UInt) -> big.UInt {
		return a.adding(b)
	}

	/// Add `a` and `b` together, and store the sum in `a`.
	///
	/// - Complexity: O(max(a.count, b.count))
	public static func += (a: inout big.UInt, b: big.UInt) {
		a.add(b, shiftedBy: 0)
	}
}

public extension big.Int {
	/// Add `a` to `b` and return the result.
	static func + (a: big.Int, b: big.Int) -> big.Int {
		switch (a.sign, b.sign) {
		case (.plus, .plus):
			return big.Int(sign: .plus, magnitude: a.magnitude + b.magnitude)
		case (.minus, .minus):
			return big.Int(sign: .minus, magnitude: a.magnitude + b.magnitude)
		case (.plus, .minus):
			if a.magnitude >= b.magnitude {
				return big.Int(sign: .plus, magnitude: a.magnitude - b.magnitude)
			} else {
				return big.Int(sign: .minus, magnitude: b.magnitude - a.magnitude)
			}
		case (.minus, .plus):
			if b.magnitude >= a.magnitude {
				return big.Int(sign: .plus, magnitude: b.magnitude - a.magnitude)
			} else {
				return big.Int(sign: .minus, magnitude: a.magnitude - b.magnitude)
			}
		}
	}

	/// Add `b` to `a` in place.
	static func += (a: inout big.Int, b: big.Int) {
		a = a + b
	}
}
