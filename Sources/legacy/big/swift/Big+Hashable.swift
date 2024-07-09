//
//  Big+Hashable.swift
//  nugg.xyz
//
//  Created by walter on 11/28/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension big.UInt: Hashable {
	// MARK: Hashing

	/// Append this `big.UInt` to the specified hasher.
	public func hash(into hasher: inout Hasher) {
		for word in self.words {
			hasher.combine(word)
		}
	}
}

extension big.Int: Hashable {
	/// Append this `big.Int` to the specified hasher.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(sign)
		hasher.combine(magnitude)
	}
}
