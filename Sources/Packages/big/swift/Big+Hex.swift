//
//  Big+Hex.swift
//  nugg.xyz
//
//  Created by walter on 12/4/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

enum HexFormat {
	case prefixed
	case noprefix
	case rlp
}

extension big.UInt {
	private func toHexRlp() -> String {
		if self.isZero { return "0x" }
		return "0x" + String(self, radix: 16)
	}

	func toHex(_ format: HexFormat = .noprefix) -> String {
		if format == .rlp { return self.toHexRlp() }

		var hexadecimal = String(self, radix: 16)

		if hexadecimal.count % 2 == 1 {
			hexadecimal += "0"
		}

		return format == .prefixed ? "0x" : "" + hexadecimal
	}

	public init?(hex: String) {
		self.init(hex.replacingOccurrences(of: "0x", with: ""), radix: 16)
	}
}

public extension big.Int {
	func toHex() -> String {
		var hexadecimal = String(self, radix: 16)
		if hexadecimal.count % 2 == 1 {
			hexadecimal = "0" + hexadecimal
		}
		return hexadecimal
	}

	init?(hex: String) {
		self.init(hex.replacingOccurrences(of: "0x", with: ""), radix: 16)
	}
}
