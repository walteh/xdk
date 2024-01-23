//
//  Data+hex.swift
//
//
//  Created by walter on 3/4/23.
//

import Foundation

public extension Data {
	func hexEncodedString() -> String {
		return map { String(format: "%02hhx", $0) }.joined()
	}

	func hexEncodedStringPrefiexed() -> String {
		return "0x\(self.hexEncodedString())"
	}
}
