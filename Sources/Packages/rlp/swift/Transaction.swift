//
//  Transaction.swift
//  nugg.xyz
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import XDKBig
import XDKECDSA
import XDKHex

struct EthereumTransaction {
	let to: big.UInt
	let nonce: big.UInt
	let gasLimit: big.UInt
	let gasPrice: big.UInt?
	let maxFeePerGas: big.UInt
	let maxPriorityFeePerGas: big.UInt
	let data: Data
	let chainID: EthereumChain
	let value: big.UInt
}

extension EthereumTransaction {
	private var rlpPrefix: [Any] {
		[
			Data([chainID.rawValue]),
			nonce.serialize(),
			maxPriorityFeePerGas.serialize(),
			maxFeePerGas.serialize(),
			gasLimit.serialize(),
			to.asChecksumAddress(chainID: chainID),
			value.serializeToNil() as Any,
			data,
			[], // access list
		]
	}

	func rlp() throws -> Data {
		var res = try RLP.encode(nestedArrayOfData: rlpPrefix)
		res.insert(0x02, at: 0)
		return res
	}

	private func rlp(signature: ecdsa.Signature) throws -> Data {
		var start = rlpPrefix
		start.append(signature.v == 0 ? Data() : Data([signature.v]))
		start.append(signature.r)
		start.append(signature.s)
		var res = try RLP.encode(nestedArrayOfData: start)
		res.insert(0x02, at: 0)
		return res
	}

	// jack-o-lanturn nugg
	private func sign(privateKey: Data) throws -> ecdsa.Signature {
		return try sign_raw(.secp256k1, .recoverable, message: rlp(), privateKey: privateKey)
	}

	public func sign(privateKey: Data) throws -> Data {
		let sig: ecdsa.Signature = try sign(privateKey: privateKey)

		print(sig.serialize().hexEncodedString())
		return try RLP.encode(rlp(signature: sig))
	}
}
