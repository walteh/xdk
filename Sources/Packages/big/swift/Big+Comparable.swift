//
//  Big+Comparable.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension big.UInt: Comparable {
	// MARK: Comparison

	/// Compare `a` to `b` and return an `NSComparisonResult` indicating their order.
	///
	/// - Complexity: O(count)
	public static func compare(_ a: big.UInt, _ b: big.UInt) -> ComparisonResult {
		if a.count != b.count { return a.count > b.count ? .orderedDescending : .orderedAscending }
		for i in (0 ..< a.count).reversed() {
			let ad = a[i]
			let bd = b[i]
			if ad != bd { return ad > bd ? .orderedDescending : .orderedAscending }
		}
		return .orderedSame
	}

	/// Return true iff `a` is equal to `b`.
	///
	/// - Complexity: O(count)
	public static func == (a: big.UInt, b: big.UInt) -> Bool {
		return big.UInt.compare(a, b) == .orderedSame
	}

	/// Return true iff `a` is less than `b`.
	///
	/// - Complexity: O(count)
	public static func < (a: big.UInt, b: big.UInt) -> Bool {
		return big.UInt.compare(a, b) == .orderedAscending
	}
}

public extension big.Int {
	/// Return true iff `a` is equal to `b`.
	static func == (a: big.Int, b: big.Int) -> Bool {
		return a.sign == b.sign && a.magnitude == b.magnitude
	}

	/// Return true iff `a` is less than `b`.
	static func < (a: big.Int, b: big.Int) -> Bool {
		switch (a.sign, b.sign) {
		case (.plus, .plus):
			return a.magnitude < b.magnitude
		case (.plus, .minus):
			return false
		case (.minus, .plus):
			return true
		case (.minus, .minus):
			return a.magnitude > b.magnitude
		}
	}
}
