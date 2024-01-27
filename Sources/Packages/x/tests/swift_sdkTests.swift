//
//  swift_sdkTests.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import XCTest
@testable import XDKX

class XDKXTests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testExample() throws {
		let err1 = URLError(.badURL, userInfo: ["hi": "there"])
		let err = x.error("hello", root: err1)

		x.log(.error).err(err).send("test")
	}

	func testExamplew() throws {
		var err: Error? = nil

		// let ok = Result.X(catch: &err) { throw x.error("hello") }
	}

	func testPerformanceExample() throws {
		// This is an example of a performance test case.
		measure {
			// Put the code you want to measure the time of here.
		}
	}
}
