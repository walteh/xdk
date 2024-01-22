//
//  Big+Sqrt.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

public extension big.UInt {
	/// Returns the integer square root of a big integer; i.e., the largest integer whose square isn't greater than `value`.
	///
	/// - Returns: floor(sqrt(self))
	func sqrt() -> big.UInt {
		// This implementation uses Newton's method.
		guard !self.isZero else { return big.UInt() }
		var x = big.UInt(1) << ((self.bitWidth + 1) / 2)
		var y: big.UInt = 0
		while true {
			y.load(self)
			y /= x
			y += x
			y >>= 1
			if x == y || x == y - 1 { break }
			x = y
		}
		return x
	}
}

public extension big.Int {
	/// Returns the integer square root of a big integer; i.e., the largest integer whose square isn't greater than `value`.
	///
	/// - Requires: self >= 0
	/// - Returns: floor(sqrt(self))
	func sqrt() -> big.Int {
		precondition(self.sign == .plus)
		return big.Int(sign: .plus, magnitude: self.magnitude.sqrt())
	}
}
