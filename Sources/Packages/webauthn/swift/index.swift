//
//  index.swift
//
//
//  Created by walter on 3/3/23.
//

import AuthenticationServices
import Foundation
import XDKAppSession
import XDKKeychain
import XDKXID

public struct JWT {
	let token: String
	let credentialID: Data
}

public typealias Challenge = XID

public protocol WebauthnDeviceCheckAPI {
	func assert(request: inout URLRequest, dataToSign: Data?) async throws
	func attest() async throws
	func initialized() throws -> Bool
}

public protocol WebauthnPasskeyAPI: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	func assertPasskey() async throws
	func attestPasskey() async throws
	func startSignInObserver() -> NSObjectProtocol
}

public protocol WebauthnRemoteAPI {
	func remote(init type: CeremonyType, credentialID: Data?) async throws -> Challenge
	func remote(authorization: ASAuthorization) async throws -> JWT
	func remote(credentialRegistration attest: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> JWT
	func remote(credentialAssertion assert: ASAuthorizationPublicKeyCredentialAssertion) async throws -> JWT
	func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data) async throws -> Bool
	func getPublicKeyProvider() -> ASAuthorizationPlatformPublicKeyCredentialProvider
	func getIsPerformingModalRequest() -> Bool
	func getUserID() -> String
}

public enum CeremonyType: String {
	case Get = "webauthn.get"
	case Create = "webauthn.create"
}
