//
//  keychain.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import XCTest
@testable import XDKKeychain

class LocalAuthenticationTests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testExample() throws {
		let ok = LocalAuthenticationClient(group: "abc").authenticationAvailable()
		XCTAssertTrue(ok)
	}

	func testPerformanceExample() throws {
		// This is an example of a performance test case.
		measure {
			// Put the code you want to measure the time of here.
		}
	}
}
