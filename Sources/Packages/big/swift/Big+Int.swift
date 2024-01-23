//
//  Big+Int.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension big.Int: SignedInteger {
	public enum Sign {
		case plus
		case minus
	}

	public typealias Magnitude = big.UInt

	/// The type representing a digit in `big.Int`'s underlying number system.
	public typealias Word = big.UInt.Word

	public static var isSigned: Bool {
		return true
	}

	/// Initializes a new big integer with the provided absolute number and sign flag.
	public init(sign: Sign, magnitude: big.UInt) {
		self.sign = (magnitude.isZero ? .plus : sign)
		self.magnitude = magnitude
	}

	/// Return true iff this integer is zero.
	///
	/// - Complexity: O(1)
	public var isZero: Bool {
		return self.magnitude.isZero
	}

	/// Returns `-1` if this value is negative and `1` if it’s positive; otherwise, `0`.
	///
	/// - Returns: The sign of this number, expressed as an integer of the same type.
	public func signum() -> big.Int {
		switch self.sign {
		case .plus:
			return self.isZero ? 0 : 1
		case .minus:
			return -1
		}
	}
}
