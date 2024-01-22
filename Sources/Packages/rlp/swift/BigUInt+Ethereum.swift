//
//  BigUInt+Ethereum.swift
//  nugg.xyz
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import big_swift
import byte_swift
import ecdsa_swift
import x_swift

extension big.UInt {
	func asChecksumAddress(chainID _: EthereumChain) -> Data {
		var dat: [UInt8] = .init(repeating: 0, count: 20)

		let stripAddress = self.serialize().reversed()

		for (i, u) in stripAddress.enumerated() {
			if i >= 20 { break }
			dat[dat.count - i - 1] = u
		}

		let hash = Data(dat).sha3(.ethereum)
		var checksum: [UInt8] = .init(repeating: 0, count: 20)

		for (i, u) in dat.enumerated() {
			checksum[i] = hash[i] >= 8 && (Byte.a <= u && u <= Byte.z) ? u + 37 : u
		}

		return Data(checksum)
	}
}
