//
//  Big+BinaryInteger.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

public extension big.UInt {
	init?<T: BinaryInteger>(exactly source: T) {
		guard source >= (0 as T) else { return nil }
		if source.bitWidth <= 2 * Word.bitWidth {
			var it = source.words.makeIterator()
			self.init(low: it.next() ?? 0, high: it.next() ?? 0)
			precondition(it.next() == nil, "Length of BinaryInteger.words is greater than its bitWidth")
		} else {
			self.init(words: source.words)
		}
	}

	init<T: BinaryInteger>(_ source: T) {
		precondition(source >= (0 as T), "big.UInt cannot represent negative values")
		self.init(exactly: source)!
	}

	init(truncatingIfNeeded source: some BinaryInteger) {
		self.init(words: source.words)
	}

	init<T: BinaryInteger>(clamping source: T) {
		if source <= (0 as T) {
			self.init()
		} else {
			self.init(words: source.words)
		}
	}
}

public extension big.Int {
	init() {
		self.init(sign: .plus, magnitude: 0)
	}

	/// Initializes a new signed big integer with the same value as the specified unsigned big integer.
	init(_ integer: big.UInt) {
		self.magnitude = integer
		self.sign = .plus
	}

	init<T>(_ source: T) where T: BinaryInteger {
		if source >= (0 as T) {
			self.init(sign: .plus, magnitude: big.UInt(source))
		} else {
			var words = Array(source.words)
			words.twosComplement()
			self.init(sign: .minus, magnitude: big.UInt(words: words))
		}
	}

	init?(exactly source: some BinaryInteger) {
		self.init(source)
	}

	init(clamping source: some BinaryInteger) {
		self.init(source)
	}

	init(truncatingIfNeeded source: some BinaryInteger) {
		self.init(source)
	}
}

extension big.UInt: ExpressibleByIntegerLiteral {
	/// Initialize a new big integer from an integer literal.
	public init(integerLiteral value: UInt64) {
		self.init(value)
	}
}

extension big.Int: ExpressibleByIntegerLiteral {
	/// Initialize a new big integer from an integer literal.
	public init(integerLiteral value: Int64) {
		self.init(value)
	}
}
