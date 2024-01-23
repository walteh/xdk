//
//  Big+Random.swift
//  nugg.xyz
//
//  Created by walter on 12/3/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension big.Int {
	/**
	 - Parameter minimum: minimum value of the integer
	 - Parameter maximum: maximum value of the integer
	 - Returns: integer x in the range: minimum <= x <= maximum
	 */
	public static func randBetween(min: big.Int, max: big.Int) -> big.Int {
		let result = self.getBytesNeeded(max - min)
		let bytesNeeded = result.0
		let mask = result.1
		var bytes = [Int](repeating: 0, count: bytesNeeded)

		let _ = SecRandomCopyBytes(
			kSecRandomDefault,
			bytesNeeded,
			&bytes
		)

		var randomValue = big.Int(0)

		for item in 0 ..< bytesNeeded {
			randomValue |= big.Int(bytes[item]) << (8 * item)
		}

		randomValue &= mask

		// Taking the randomValue module would increase concentration in a specific region of the range and break the uniform distribution, raising security concerns.
		// To avoid this, we retry the method until the value satisfies the range.
		if min + randomValue > max {
			return self.randBetween(min: min, max: max)
		}
		return min + randomValue
	}

	static func getBytesNeeded(_ request: big.Int) -> (Int, big.Int) {
		var range = request
		var bitsNeeded = 0
		var bytesNeeded = 0
		var mask = big.Int(1)

		while range > 0 {
			if bitsNeeded % 8 == 0 {
				bytesNeeded += 1
			}
			bitsNeeded += 1
			mask = (mask << 1) | big.Int(1)
			range = range >> 1
		}
		return (bytesNeeded, mask)
	}
}
