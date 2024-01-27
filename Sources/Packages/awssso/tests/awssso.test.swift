//
//  awssso.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import AWSSSOOIDC
import XCTest
import XDK
import XDKKeychain

@testable import XDKAWSSSO

class big_tests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testExample() async throws {
		let keychain = XDK.InMemoryStorage()
		let selectedRegion = "us-east-1"

		let val = "https://nuggxyz.awsapps.com/start#/"
		guard let startURI = URL(string: val) else {
			throw URLError(.init(rawValue: 0), userInfo: ["uri": val])
		}

		var err: Error? = nil

		guard let client = Result.X { try AWSSSOOIDC.SSOOIDCClient(region: "us-east-1") }.to(&err) else {
			XCTFail("failed to create client" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		var promptURL: XDKAWSSSO.UserSignInData? = nil
		guard let resp = await XDKAWSSSO.signInWithSSO(awsssoAPI: client, storageAPI: keychain, ssoRegion: selectedRegion, startURL: startURI) { url in
			promptURL = url
		}.to(&err) else {
			XCTFail("failed to sign in" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		let sess = AWSSSOUserSession(
			account: AccountRole(accountID: "324802912585", role: "AWSAdministratorAccess"),
			region: "us-east-1",
			service: "s3",
			resource: nil,
			accessToken: resp
		)

		XCTAssertNotNil(promptURL)

		guard let url = await XDKAWSSSO.loadAWSConsole(userSession: sess, storageAPI: keychain).to(&err) else {
			XCTFail("failed to load console" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		XCTAssertNotNil(url)
	}

	func testPerformanceExample() throws {
		// This is an example of a performance test case.
		measure {
			// Put the code you want to measure the time of here.
		}
	}
}
