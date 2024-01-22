//
//  Big+Shift.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension big.UInt {
	// MARK: Shift Operators

	internal func shiftedLeft(by amount: Word) -> big.UInt {
		guard amount > 0 else { return self }

		let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
		let up = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
		let down = Word(Word.bitWidth) - up

		var result = big.UInt()
		if up > 0 {
			var i = 0
			var lowbits: Word = 0
			while i < self.count || lowbits > 0 {
				let word = self[i]
				result[i + ext] = word << up | lowbits
				lowbits = word >> down
				i += 1
			}
		} else {
			for i in 0 ..< self.count {
				result[i + ext] = self[i]
			}
		}
		return result
	}

	internal mutating func shiftLeft(by amount: Word) {
		guard amount > 0 else { return }

		let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
		let up = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
		let down = Word(Word.bitWidth) - up

		if up > 0 {
			var i = 0
			var lowbits: Word = 0
			while i < self.count || lowbits > 0 {
				let word = self[i]
				self[i] = word << up | lowbits
				lowbits = word >> down
				i += 1
			}
		}
		if ext > 0, self.count > 0 {
			self.shl(byWords: ext)
		}
	}

	internal func shiftedRight(by amount: Word) -> big.UInt {
		guard amount > 0 else { return self }
		guard amount < self.bitWidth else { return 0 }

		let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
		let down = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
		let up = Word(Word.bitWidth) - down

		var result = big.UInt()
		if down > 0 {
			var highbits: Word = 0
			for i in (ext ..< self.count).reversed() {
				let word = self[i]
				result[i - ext] = highbits | word >> down
				highbits = word << up
			}
		} else {
			for i in (ext ..< self.count).reversed() {
				result[i - ext] = self[i]
			}
		}
		return result
	}

	internal mutating func shiftRight(by amount: Word) {
		guard amount > 0 else { return }
		guard amount < self.bitWidth else { self.clear(); return }

		let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
		let down = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
		let up = Word(Word.bitWidth) - down

		if ext > 0 {
			self.shr(byWords: ext)
		}
		if down > 0 {
			var i = self.count - 1
			var highbits: Word = 0
			while i >= 0 {
				let word = self[i]
				self[i] = highbits | word >> down
				highbits = word << up
				i -= 1
			}
		}
	}

	public static func >>= <Other: BinaryInteger>(lhs: inout big.UInt, rhs: Other) {
		if rhs < (0 as Other) {
			lhs <<= (0 - rhs)
		} else if rhs >= lhs.bitWidth {
			lhs.clear()
		} else {
			lhs.shiftRight(by: UInt(rhs))
		}
	}

	public static func <<=< Other: BinaryInteger > (lhs: inout big.UInt, rhs: Other) {
		if rhs < (0 as Other) {
			lhs >>= (0 - rhs)
			return
		}
		lhs.shiftLeft(by: Word(exactly: rhs)!)
	}

	public static func >> <Other: BinaryInteger>(lhs: big.UInt, rhs: Other) -> big.UInt {
		if rhs < (0 as Other) {
			return lhs << (0 - rhs)
		}
		if rhs > Word.max {
			return 0
		}
		return lhs.shiftedRight(by: UInt(rhs))
	}

	public static func << <Other: BinaryInteger>(lhs: big.UInt, rhs: Other) -> big.UInt {
		if rhs < (0 as Other) {
			return lhs >> (0 - rhs)
		}
		return lhs.shiftedLeft(by: Word(exactly: rhs)!)
	}
}

public extension big.Int {
	internal func shiftedLeft(by amount: Word) -> big.Int {
		return big.Int(sign: self.sign, magnitude: self.magnitude.shiftedLeft(by: amount))
	}

	internal mutating func shiftLeft(by amount: Word) {
		self.magnitude.shiftLeft(by: amount)
	}

	internal func shiftedRight(by amount: Word) -> big.Int {
		let m = self.magnitude.shiftedRight(by: amount)
		return big.Int(sign: self.sign, magnitude: self.sign == .minus && m.isZero ? 1 : m)
	}

	internal mutating func shiftRight(by amount: Word) {
		magnitude.shiftRight(by: amount)
		if sign == .minus, magnitude.isZero {
			magnitude.load(1)
		}
	}

	static func &<< (left: big.Int, right: big.Int) -> big.Int {
		return left.shiftedLeft(by: right.words[0])
	}

	static func &<<= (left: inout big.Int, right: big.Int) {
		left.shiftLeft(by: right.words[0])
	}

	static func &>> (left: big.Int, right: big.Int) -> big.Int {
		return left.shiftedRight(by: right.words[0])
	}

	static func &>>= (left: inout big.Int, right: big.Int) {
		left.shiftRight(by: right.words[0])
	}

	static func << <Other: BinaryInteger>(lhs: big.Int, rhs: Other) -> big.Int {
		guard rhs >= (0 as Other) else { return lhs >> (0 - rhs) }
		return lhs.shiftedLeft(by: Word(rhs))
	}

	static func <<=< Other: BinaryInteger > (lhs: inout big.Int, rhs: Other) {
		if rhs < (0 as Other) {
			lhs >>= (0 - rhs)
		} else {
			lhs.shiftLeft(by: Word(rhs))
		}
	}

	static func >> <Other: BinaryInteger>(lhs: big.Int, rhs: Other) -> big.Int {
		guard rhs >= (0 as Other) else { return lhs << (0 - rhs) }
		return lhs.shiftedRight(by: Word(rhs))
	}

	static func >>= <Other: BinaryInteger>(lhs: inout big.Int, rhs: Other) {
		if rhs < (0 as Other) {
			lhs <<= (0 - rhs)
		} else {
			lhs.shiftRight(by: Word(rhs))
		}
	}
}
