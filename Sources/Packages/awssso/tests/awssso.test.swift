//
//  awssso.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import AWSSSO
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
		let storageAPI = XDK.InMemoryStorage() as StorageAPI
		let selectedRegion = "us-east-1"

		let val = "https://nuggxyz.awsapps.com/start#/"
		guard let startURI = URL(string: val) else {
			throw URLError(.init(rawValue: 0), userInfo: ["uri": val])
		}

		var err: Error? = nil

		guard let oidc = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: "us-east-1") }).to(&err) else {
			XCTFail("failed to create client" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		guard let sso = Result.X({ try AWSSSO.SSOClient(region: "us-east-1") }).to(&err) else {
			XCTFail("failed to create client" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		var promptURL: XDKAWSSSO.UserSignInData? = nil
		guard let resp = await XDKAWSSSO.signin(ssooidc: oidc, storageAPI: storageAPI, ssoRegion: selectedRegion, startURL: startURI) { url in
			promptURL = url
		}.to(&err) else {
			XCTFail("failed to sign in" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		let role = RoleInfo(roleName: "admin", accountID: "324802912585")

		let account = AccountInfo(accountID: "324802912585", accountName: "hi", roles: [role], accountEmail: "xyz@xyz.com")

		let sess = AWSSSOUserSession(
			storageAPI: storageAPI,
			account: account
		)

		guard let _ = await sess.refresh(accessToken: resp, storageAPI: storageAPI).to(&err) else {
			XCTFail("failed to refresh" + (err?.localizedDescription ?? "unknown error"))
			return
		}

		XCTAssertNotNil(promptURL)

		guard let url = await XDKAWSSSO.generateAWSConsoleURL(sso: sso, account: account, managedRegion: sess, storageAPI: storageAPI, accessToken: resp).to(&err) else {
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
