//
//  awssso.test.swift
//  swift-sdkTests
//
//  Created by walter on 3/3/23.
//

import Logging
import Testing
import Foundation
import XDK
import XDKLogging
import Err
import LogEvent

@testable import XDKAWSSSO




@Test
func testGetServices() throws {
	let res = XDKAWSSSO.loadTheServices()
	log(.info).info("data", res).send("okay")
	#expect(res.count > 0)
}

// @Test
@err  func dontTestExample() async throws {
	let storageAPI = XDK.InMemoryStorage() as StorageAPI
	let selectedRegion = "us-east-1"

	let val = "https://nuggxyz.awsapps.com/start#/"
	guard let startURI = URL(string: val) else {
		throw error("invalid url").info("url", val)
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
			log(.info).info("url", url.activationURLWithCode).send("okay")
			print("====================================")
		}
	).get() else {
		#expect(false, .init(rawValue: "failed to generate token" + (err.localizedDescription ?? "unknown error")))
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


	guard let url = await XDKAWSSSO.generateAWSConsoleURLUsingSSO(
		client: client,
		account: account,
		role: role,
		managedRegion: sess,
		storageAPI: storageAPI,
		accessToken: resp,
		isSignedIn: true
	).get() else {
		#expect(false, .init(rawValue: "failed to generate url" + (err.localizedDescription ?? "unknown error")))
		return
	}
}

