//
//  File.swift
//
//
//  Created by walter on 1/23/24.
//

import Foundation
import AuthenticationServices
import XDKKeychain
import XDKAppSession

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
	
	internal let publicKeyProvider: ASAuthorizationPlatformPublicKeyCredentialProvider
	internal var isPerformingModalRequest: Bool = false
	
	public func getPublicKeyProvider() -> ASAuthorizationPlatformPublicKeyCredentialProvider {
		return publicKeyProvider
	}
	
	public func getIsPerformingModalRequest() -> Bool {
		return isPerformingModalRequest
	}
	
	public func getUserID() -> String {
		return sessionAPI.ID().string()
	}
}
