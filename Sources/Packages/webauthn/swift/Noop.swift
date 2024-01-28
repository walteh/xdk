//
//  Noop.swift
//
//
//  Created by walter on 3/5/23.
//

import AuthenticationServices
import Foundation
import XDKXID

public class WebauthnNoopRemoteClient: WebauthnRemoteAPI {
	let userID = XID.build()

	public func getPublicKeyProvider() -> ASAuthorizationPlatformPublicKeyCredentialProvider {
		return .init(relyingPartyIdentifier: "noop")
	}

	public func getIsPerformingModalRequest() -> Bool {
		false
	}

	public func getUserID() -> String {
		return self.userID.string()
	}

	public init() {}

	public func remote(init _: CeremonyType, credentialID _: Data?) async -> Result<Challenge, Error> {
		return .success(XID.build())
	}

	public func remote(authorization _: ASAuthorization) async -> Result<JWT, Error> {
		return .success(.init(token: "", credentialID: Data()))
	}

	public func remote(credentialRegistration _: ASAuthorizationPlatformPublicKeyCredentialRegistration) async -> Result<JWT, Error> {
		return .success(.init(token: "", credentialID: Data()))
	}

	public func remote(credentialAssertion _: ASAuthorizationPublicKeyCredentialAssertion) async -> Result<JWT, Error> {
		return .success(.init(token: "", credentialID: Data()))
	}

	public func remote(deviceAttestation _: Data, clientDataJSON _: String, using _: Data) async -> Result<Void, Error> {
		return .success(())
	}
}
