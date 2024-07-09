//
//  BigUInt+Ethereum.swift
//  nugg.xyz
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation
import MicroDeterministicECDSA
import XDK
import BigInt
import XDKByte

extension BigUInt {
	public init?(hex: String) {
		self.init(hex.replacingOccurrences(of: "0x", with: ""), radix: 16)
	}
	func serializeToNil() -> Data? {
		let res = self.serialize()
		return BigUInt(res).isZero ? nil : res
	}
	func asChecksumAddress(chainID _: EthereumChain) -> Data {
		var dat: [UInt8] = .init(repeating: 0, count: 20)

		let stripAddress = serialize().reversed()

		for (i, u) in stripAddress.enumerated() {
			if i >= 20 { break }
			dat[dat.count - i - 1] = u
		}

		let hash = MicroDeterministicECDSA.hash(.Keccak256, 256, Data(dat))
		var checksum: [UInt8] = .init(repeating: 0, count: 20)

		for (i, u) in dat.enumerated() {
			checksum[i] = hash[i] >= 8 && (Byte.a <= u && u <= Byte.z) ? u + 37 : u
		}

		return Data(checksum)
	}
}
