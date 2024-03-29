//
//  ecdsa.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import XCTest
import XDK
import XDKHex
@testable import XDKECDSA

class ecdsaTests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testMicroEcc() throws {
		let res = try sign_raw(.secp256k1, .recoverable, message: "hello".data, privateKey: "00bb19aec0b23e3b0a221fe5c67cd7fe5ec05f882d7d79235b1a0640d3021a4f".hexToData())

		print(res.serialize().hexEncodedString())
	}
}
