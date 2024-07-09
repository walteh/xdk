//
//  Transaction__Tests.swift
//  Tests
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import XCTest
@testable import XDKRLP

private struct TestCase {
	let transaction: EthereumTransaction
	let privatekey: String
	let want: String
}

final class Transaction__Tests: XCTestCase {
	override func setUpWithError() throws {}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}
}

extension Transaction__Tests {
	private struct _args {
		let transaction: EthereumTransaction
		let privatekey: String
		let want: String
	}

	private func _test(args: _args) throws {
		let got = try args.transaction.sign(privateKey: args.privatekey.hexToData())
		XCTAssertEqual(got.hexEncodedString(), args.want)
	}

	func testA() throws {
		let tx = EthereumTransaction(
			to: .init(hex: "aaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbb")!,
			nonce: .init(88),
			gasLimit: .init(77),
			gasPrice: nil,
			maxFeePerGas: .init(66),
			maxPriorityFeePerGas: .init(33),
			data: "abcd".data,
			chainID: .goerli,
			value: .init(stringLiteral: "100000000000000001")
		)

		print(try! tx.rlp().hexEncodedString())

		try self._test(args: .init(
			transaction: EthereumTransaction(
				to: .init(hex: "aaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbb")!,
				nonce: .init(88),
				gasLimit: .init(77),
				gasPrice: nil,
				maxFeePerGas: .init(66),
				maxPriorityFeePerGas: .init(33),
				data: "abcd".data,
				chainID: .goerli,
				value: .init(stringLiteral: "100000000000000001")
			),
			privatekey: "00bb19aec0b23e3b0a221fe5c67cd7fe5ec05f882d7d79235b1a0640d3021a4f",
			want: "b86f02f86c055821424d9400aaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbb88016345785d8a00018461626364c080a03b25864dc856704db0c837d30ef36c6c649a81b79e6d5543c8ccbc77c7665a96a0592791387cb503f9548fdc4629fc31ac9f778fc131435f73ff8729519d571772"
		))
	}
}
