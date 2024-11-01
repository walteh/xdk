//
//  awssso.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import Logging
import Testing
import XCTest
import XDK
import XDKLogging
import Err

@testable import XDKAWSSSO

// override func setUpWithError() throws {
// 	LoggingSystem.bootstrap { label in
// 		var level: Logger.Level = .trace
// 		switch label {
// 		case "URLSessionHTTPClient", "SSOClient", "SSOOIDCClient":
// 			level = .error
// 		default:
// 			level = .trace
// 		}
// 		return XDKLogging.ConsoleLogger(label: label, level: level, metadata: .init())
// 	}
// 	// Put setup code here. This method is called before the invocation of each test method in the class.
// }

// override func tearDownWithError() throws {
// 	// Put teardown code here. This method is called after the invocation of each test method in the class.
// }
@Test
func testGetServices() throws {
	let res = XDKAWSSSO.loadTheServices()
	XDK.Log(.info).info("data", res).send("okay")
	XCTAssertNotNil(res)
}
// @Test
@err  func dontTestExample() async throws {
	let storageAPI = XDK.InMemoryStorage() as StorageAPI
	let selectedRegion = "us-east-1"

	let val = "https://nuggxyz.awsapps.com/start#/"
	guard let startURI = URL(string: val) else {
		throw URLError(.init(rawValue: 0), userInfo: ["uri": val])
	}


	let client = try! AWSSSOSDKProtocolWrappedImpl(ssoRegion: selectedRegion)

	// var promptURL: XDKAWSSSO.AWSSSOSignInCodeData?
	guard let resp = await XDKAWSSSO.generateSSOAccessTokenUsingBrowserIfNeeded(
		client: client,
		storage: storageAPI,
		session: XDK.NoopAppSession(),
		ssoRegion: selectedRegion,
		startURL: startURI,
		callback: { @Sendable url in
			#expect(url != nil)
			print("====================================")
			// open the browser with the url
			XDK.Log(.info).info("url", url.activationURLWithCode).send("okay")
			print("====================================")
		}
	).get() else {
		XCTFail("failed to sign in" + (err?.localizedDescription ?? "unknown error"))
		return
	}

	let role = RoleInfo(roleName: "admin", accountID: "324802912585")

	let account = AccountInfo(accountID: "324802912585", accountName: "hi", roles: [role], accountEmail: "xyz@xyz.com")

	let sess = SimpleManagedRegionService(
		region: selectedRegion,
		service: "s3"
	)

	// guard let _ = await sess.refresh(accessToken: resp, storageAPI: storageAPI).get() else {
	// 	XCTFail("failed to refresh" + (err?.localizedDescription ?? "unknown error"))
	// 	return
	// }


	let url = await XDKAWSSSO.generateAWSConsoleURLUsingSSO(
		client: client,
		account: account,
		role: role,
		managedRegion: sess,
		storageAPI: storageAPI,
		accessToken: resp,
		isSignedIn: true
	).get()

	#expect(err == nil)

	#expect(url != nil)
}

// func testPerformanceExample() throws {
// 	// This is an example of a performance test case.
// 	measure {
// 		// Put the code you want to measure the time of here.
// 	}
// }
