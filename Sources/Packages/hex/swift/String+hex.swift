//
//  File.swift
//
//
//  Created by walter on 3/4/23.
//

import Foundation

extension String {
	enum ExtendedEncoding {
		case hex
	}

	private func data(using _: ExtendedEncoding) -> Data? {
		let hexStr = self.dropFirst(self.hasPrefix("0x") ? 2 : 0)

		guard hexStr.count % 2 == 0 else { return nil }

		var newData = Data(capacity: hexStr.count / 2)

		var indexIsEven = true
		for i in hexStr.indices {
			if indexIsEven {
				let byteRange = i ... hexStr.index(after: i)
				guard let byte = UInt8(hexStr[byteRange], radix: 16) else { return nil }
				newData.append(byte)
			}
			indexIsEven.toggle()
		}
		return newData
	}

	public func hexToData() -> Data { self.data(using: .hex) ?? Data() }
}

extension String {
	func deHex() -> String {
		return self.replacingOccurrences(of: "0x", with: "")
	}

	func toUInt64() -> UInt64 {
		if self.hasPrefix("0x") {
			let num = UInt64(self.deHex(), radix: 16)
			if num == nil {
				return 0
			}
			return num!
		}

		let num = UInt64(self, radix: 10)
		if num == nil {
			return 0
		}

		return num!
	}

	func toInt64() -> Int64 {
		if self.hasPrefix("0x") {
			let num = Int64(self.deHex(), radix: 16)

			if num == nil {
				return 0
			}
			return num!
		}

		let num = Int64(self, radix: 10)
		if num == nil {
			return 0
		}

		return num!
	}
}
