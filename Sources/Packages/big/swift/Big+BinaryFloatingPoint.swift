//
//  Big+Float.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

//
//  Floating Point Conversion.swift
//  big.Int
//
//  Created by Károly Lőrentey on 2017-08-11.
//  Copyright © 2016-2017 Károly Lőrentey.
//

public extension big.UInt {
	init?<T: BinaryFloatingPoint>(exactly source: T) {
		guard source.isFinite else { return nil }
		guard !source.isZero else { self = 0; return }
		guard source.sign == .plus else { return nil }
		let value = source.rounded(.towardZero)
		guard value == source else { return nil }
		assert(value.floatingPointClass == .positiveNormal)
		assert(value.exponent >= 0)
		let significand = value.significandBitPattern
		self = (big.UInt(1) << value.exponent) + big.UInt(significand) >> (T.significandBitCount - Int(value.exponent))
	}

	init(_ source: some BinaryFloatingPoint) {
		self.init(exactly: source.rounded(.towardZero))!
	}
}

public extension big.Int {
	init?(exactly source: some BinaryFloatingPoint) {
		switch source.sign {
		case .plus:
			guard let magnitude = big.UInt(exactly: source) else { return nil }
			self = big.Int(sign: .plus, magnitude: magnitude)
		case .minus:
			guard let magnitude = big.UInt(exactly: -source) else { return nil }
			self = big.Int(sign: .minus, magnitude: magnitude)
		}
	}

	init(_ source: some BinaryFloatingPoint) {
		self.init(exactly: source.rounded(.towardZero))!
	}
}

public extension BinaryFloatingPoint where RawExponent: FixedWidthInteger, RawSignificand: FixedWidthInteger {
	init(_ value: big.Int) {
		guard !value.isZero else { self = 0; return }
		let v = value.magnitude
		let bitWidth = v.bitWidth
		var exponent = bitWidth - 1
		let shift = bitWidth - Self.significandBitCount - 1
		var significand = value.magnitude >> (shift - 1)
		if significand[0] & 3 == 3 { // Handle rounding
			significand >>= 1
			significand += 1
			if significand.trailingZeroBitCount >= Self.significandBitCount {
				exponent += 1
			}
		} else {
			significand >>= 1
		}
		let bias = 1 << (Self.exponentBitCount - 1) - 1
		guard exponent <= bias else { self = Self.infinity; return }
		significand &= 1 << Self.significandBitCount - 1
		self = Self(sign: value.sign == .plus ? .plus : .minus,
		            exponentBitPattern: RawExponent(bias + exponent),
		            significandBitPattern: RawSignificand(significand))
	}

	init(_ value: big.UInt) {
		self.init(big.Int(sign: .plus, magnitude: value))
	}
}
