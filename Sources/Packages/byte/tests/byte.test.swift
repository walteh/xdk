//
//  byte.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import XCTest
@testable import XDKByte

class byteTests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	class UInt32__Bytes__Tests: XCTestCase {
		func testByteArrayLittleEndian() {
			let subject: UInt32 = 0x12345
			let expected: [UInt8] = [0x01, 0x23, 0x45]

			XCTAssertEqual(subject.byteArrayLittleEndian, expected)
		}
	}
}
