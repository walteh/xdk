//
//  awssso.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import AWSSSOOIDC
import XCTest
import XDKKeychain
import XDKX

@testable import XDKAWSSSO

class big_tests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testExample() async throws {
		let keychain = XDKKeychain.NoopClient()
		let selectedRegion = "us-east-1"

		let val = "https://nuggxyz.awsapps.com/start#/"
		guard let startURI = URL(string: val) else {
			throw URLError(.init(rawValue: 0), userInfo: ["uri": val])
		}

		let (client, err) = Result.X { try AWSSSOOIDC.SSOOIDCClient(region: "us-east-1") }.validate()
		XCTAssertNil(err)

		var promptURL: XDKAWSSSO.UserSignInData? = nil
		let (resp, err2) = await XDKAWSSSO.signInWithSSO(awsssoAPI: client, keychainAPI: keychain, ssoRegion: selectedRegion, startURL: startURI, promptUser: { url in
			promptURL = url
		}).validate()
		XCTAssertNil(err2)

		let sess = AWSSSOUserSession(
			account: AccountRole(accountID: "324802912585", role: "AWSAdministratorAccess"),
			region: "us-east-1",
			service: "s3",
			resource: nil,
			accessToken: resp
		)

		XCTAssertNotNil(promptURL)

		let url = await XDKAWSSSO.loadAWSConsole(userSession: sess, keychain: keychain).validate()
		XCTAssertNotNil(url)
	}

	func testPerformanceExample() throws {
		// This is an example of a performance test case.
		measure {
			// Put the code you want to measure the time of here.
		}
	}
}
