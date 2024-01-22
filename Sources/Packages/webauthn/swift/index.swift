//
//  File.swift
//
//
//  Created by walter on 3/3/23.
//

import AuthenticationServices
import Foundation
import keychain_swift
import sdk_session

public protocol WebauthnAPIProtocol {
	associatedtype SESSION = session.API
	associatedtype KEYCHAIN = keychain.API
	func Init(sessionID: Data, type: webauthn.CeremonyType, credentialID: Data?) async throws -> webauthn.Challenge
	func remote(authorization: ASAuthorization) async throws -> webauthn.JWT
	func remote(credentialRegistration attest: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> webauthn.JWT
	func remote(credentialAssertion assert: ASAuthorizationPublicKeyCredentialAssertion) async throws -> webauthn.JWT
	func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data, sessionID: Data) async throws -> Bool
}

public protocol WebauthnDeviceCheckProtocol {
	func assert(request: inout URLRequest, dataToSign: Data?) async throws
	func attest() async throws
	func initialized() -> Bool
}

public protocol WebauthnPasskeyProtocol: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	func assertPasskey() async throws
	func attestPasskey() async throws
	func startSignInObserver() -> NSObjectProtocol
	var publicKeyProvider: ASAuthorizationPlatformPublicKeyCredentialProvider { get }
	var isPerformingModalRequest: Bool { get }
}

public enum webauthn {
	public typealias API = WebauthnAPIProtocol

	public typealias Noop = WebauthnNoopAPI

	public enum passkey {
		public typealias API = WebauthnPasskeyProtocol
	}

	public enum devicecheck {
		public typealias API = WebauthnDeviceCheckProtocol
	}

	public struct JWT {
		let token: String
		let credentialID: Data
	}

	public typealias Challenge = Data

	public enum CeremonyType: String {
		case Get = "webauthn.get"
		case Create = "webauthn.create"
	}
}
