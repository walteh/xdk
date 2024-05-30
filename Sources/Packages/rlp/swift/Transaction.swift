//
//  Transaction.swift
//  nugg.xyz
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import XDKBig
import MicroDeterministicECDSA
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
			Data([self.chainID.rawValue]),
			self.nonce.serialize(),
			self.maxPriorityFeePerGas.serialize(),
			self.maxFeePerGas.serialize(),
			self.gasLimit.serialize(),
			self.to.asChecksumAddress(chainID: self.chainID),
			self.value.serializeToNil() as Any,
			self.data,
			[], // access list
		]
	}

	func rlp() throws -> Data {
		var res = try RLP.encode(nestedArrayOfData: self.rlpPrefix)
		res.insert(0x02, at: 0)
		return res
	}

	private func rlp(signature: Signature) throws -> Data {
		var start = self.rlpPrefix
		start.append(signature.v == 0 ? Data() : Data([signature.v]))
		start.append(signature.r)
		start.append(signature.s)
		var res = try RLP.encode(nestedArrayOfData: start)
		res.insert(0x02, at: 0)
		return res
	}

	// jack-o-lanturn nugg
	private func sign(privateKey: Data) throws -> MicroDeterministicECDSA.Signature {
		return try MicroDeterministicECDSA.sign(message: self.rlp(), privateKey: privateKey, on: .secp256k1, as: .EthereumRecoverable)
	}

	public func sign(privateKey: Data) throws -> Data {
		let sig: MicroDeterministicECDSA.Signature = try self.sign(privateKey: privateKey)

		print(sig.serialize().hexEncodedString())
		return try RLP.encode(self.rlp(signature: sig))
	}
}
