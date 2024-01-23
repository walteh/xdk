//
//  Client.swift
//
//
//  Created by walter on 1/23/24.
//

import AuthenticationServices
import Foundation
import XDKAppSession
import XDKKeychain

class WebauthnAuthenticationServicesClient: NSObject {
	let host: URL

	let sessionAPI: any XDKAppSession.AppSessionAPI
	let keychainAPI: any XDKKeychain.KeychainAPI

	public init(host: String, keychainAPI: any XDKKeychain.KeychainAPI, sessionAPI: any XDKAppSession.AppSessionAPI, relyingPartyIdentifier: String) {
		self.host = .init(string: host)!
		self.keychainAPI = keychainAPI
		self.sessionAPI = sessionAPI
		self.publicKeyProvider = .init(relyingPartyIdentifier: relyingPartyIdentifier)
		super.init()
	}

	let publicKeyProvider: ASAuthorizationPlatformPublicKeyCredentialProvider
	var isPerformingModalRequest: Bool = false

	public func getPublicKeyProvider() -> ASAuthorizationPlatformPublicKeyCredentialProvider {
		return self.publicKeyProvider
	}

	public func getIsPerformingModalRequest() -> Bool {
		return self.isPerformingModalRequest
	}

	public func getUserID() -> String {
		return self.sessionAPI.ID().string()
	}
}