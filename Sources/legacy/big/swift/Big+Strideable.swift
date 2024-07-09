//
//  Big+Strideable.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

extension big.UInt: Strideable {
	/// A type that can represent the distance between two values ofa `big.UInt`.
	public typealias Stride = big.Int

	/// Adds `n` to `self` and returns the result. Traps if the result would be less than zero.
	public func advanced(by n: big.Int) -> big.UInt {
		return n.sign == .minus ? self - n.magnitude : self + n.magnitude
	}

	/// Returns the (potentially negative) difference between `self` and `other` as a `big.Int`. Never traps.
	public func distance(to other: big.UInt) -> big.Int {
		return big.Int(other) - big.Int(self)
	}
}

extension big.Int: Strideable {
	public typealias Stride = big.Int

	/// Returns `self + n`.
	public func advanced(by n: Stride) -> big.Int {
		return self + n
	}

	/// Returns `other - self`.
	public func distance(to other: big.Int) -> Stride {
		return other - self
	}
}
