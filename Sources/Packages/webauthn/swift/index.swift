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
	func assert(request: inout URLRequest, dataToSign: Data?) async -> Result<Void, Error>
	func attest() async -> Result<Void, Error>
	func initialized() -> Result<Bool, Error>
}

public protocol WebauthnPasskeyAPI: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	func assertPasskey() async -> Result<Void, Error>
	func attestPasskey() async -> Result<Void, Error>
	func startSignInObserver() -> NSObjectProtocol
}

public protocol WebauthnRemoteAPI {
	func remote(init type: CeremonyType, credentialID: Data?) async -> Result<Challenge, Error>
	func remote(authorization: ASAuthorization) async -> Result<JWT, Error>
	func remote(credentialRegistration attest: ASAuthorizationPlatformPublicKeyCredentialRegistration) async -> Result<JWT, Error>
	func remote(credentialAssertion assert: ASAuthorizationPublicKeyCredentialAssertion) async -> Result<JWT, Error>
	func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data) async -> Result<Void, Error>
	func getPublicKeyProvider() -> ASAuthorizationPlatformPublicKeyCredentialProvider
	func getIsPerformingModalRequest() -> Bool
	func getUserID() -> String
}

public enum CeremonyType: String {
	case Get = "webauthn.get"
	case Create = "webauthn.create"
}
