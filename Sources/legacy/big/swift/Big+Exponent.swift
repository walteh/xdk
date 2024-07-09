//
//  Big+Exponent.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

public extension big.UInt {
	// MARK: Exponentiation

	/// Returns this integer raised to the power `exponent`.
	///
	/// This function calculates the result by [successively squaring the base while halving the exponent][expsqr].
	///
	/// [expsqr]: https://en.wikipedia.org/wiki/Exponentiation_by_squaring
	///
	/// - Note: This function can be unreasonably expensive for large exponents, which is why `exponent` is
	///         a simple integer value. If you want to calculate big exponents, you'll probably need to use
	///         the modulo arithmetic variant.
	/// - Returns: 1 if `exponent == 0`, otherwise `self` raised to `exponent`. (This implies that `0.power(0) == 1`.)
	/// - SeeAlso: `big.UInt.power(_:, modulus:)`
	/// - Complexity: O((exponent * self.count)^log2(3)) or somesuch. The result may require a large amount of memory, too.
	func power(_ exponent: Int) -> big.UInt {
		if exponent == 0 { return 1 }
		if exponent == 1 { return self }
		if exponent < 0 {
			precondition(!self.isZero)
			return self == 1 ? 1 : 0
		}
		if self <= 1 { return self }
		var result = big.UInt(1)
		var b = self
		var e = exponent
		while e > 0 {
			if e & 1 == 1 {
				result *= b
			}
			e >>= 1
			b *= b
		}
		return result
	}

	/// Returns the remainder of this integer raised to the power `exponent` in modulo arithmetic under `modulus`.
	///
	/// Uses the [right-to-left binary method][rtlb].
	///
	/// [rtlb]: https://en.wikipedia.org/wiki/Modular_exponentiation#Right-to-left_binary_method
	///
	/// - Complexity: O(exponent.count * modulus.count^log2(3)) or somesuch
	func power(_ exponent: big.UInt, modulus: big.UInt) -> big.UInt {
		precondition(!modulus.isZero)
		if modulus == (1 as big.UInt) { return 0 }
		let shift = modulus.leadingZeroBitCount
		let normalizedModulus = modulus << shift
		var result = big.UInt(1)
		var b = self
		b.formRemainder(dividingBy: normalizedModulus, normalizedBy: shift)
		for var e in exponent.words {
			for _ in 0 ..< Word.bitWidth {
				if e & 1 == 1 {
					result *= b
					result.formRemainder(dividingBy: normalizedModulus, normalizedBy: shift)
				}
				e >>= 1
				b *= b
				b.formRemainder(dividingBy: normalizedModulus, normalizedBy: shift)
			}
		}
		return result
	}
}

public extension big.Int {
	/// Returns this integer raised to the power `exponent`.
	///
	/// This function calculates the result by [successively squaring the base while halving the exponent][expsqr].
	///
	/// [expsqr]: https://en.wikipedia.org/wiki/Exponentiation_by_squaring
	///
	/// - Note: This function can be unreasonably expensive for large exponents, which is why `exponent` is
	///         a simple integer value. If you want to calculate big exponents, you'll probably need to use
	///         the modulo arithmetic variant.
	/// - Returns: 1 if `exponent == 0`, otherwise `self` raised to `exponent`. (This implies that `0.power(0) == 1`.)
	/// - SeeAlso: `big.UInt.power(_:, modulus:)`
	/// - Complexity: O((exponent * self.count)^log2(3)) or somesuch. The result may require a large amount of memory, too.
	func power(_ exponent: Int) -> big.Int {
		return big.Int(sign: self.sign == .minus && exponent & 1 != 0 ? .minus : .plus,
		               magnitude: self.magnitude.power(exponent))
	}

	/// Returns the remainder of this integer raised to the power `exponent` in modulo arithmetic under `modulus`.
	///
	/// Uses the [right-to-left binary method][rtlb].
	///
	/// [rtlb]: https://en.wikipedia.org/wiki/Modular_exponentiation#Right-to-left_binary_method
	///
	/// - Complexity: O(exponent.count * modulus.count^log2(3)) or somesuch
	func power(_ exponent: big.Int, modulus: big.Int) -> big.Int {
		precondition(!modulus.isZero)
		if modulus.magnitude == 1 { return 0 }
		if exponent.isZero { return 1 }
		if exponent == 1 { return self.modulus(modulus) }
		if exponent < 0 {
			precondition(!self.isZero)
			guard magnitude == 1 else { return 0 }
			guard sign == .minus else { return 1 }
			guard exponent.magnitude[0] & 1 != 0 else { return 1 }
			return big.Int(modulus.magnitude - 1)
		}
		let power = self.magnitude.power(exponent.magnitude,
		                                 modulus: modulus.magnitude)
		if self.sign == .plus || exponent.magnitude[0] & 1 == 0 || power.isZero {
			return big.Int(power)
		}
		return big.Int(modulus.magnitude - power)
	}
}
