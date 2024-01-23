//
//  File.swift
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
		return userID.string()
	}
	
	
	public init() {}

	public func remote(init type: CeremonyType, credentialID _: Data?) async throws -> Challenge {
		return XID.build()
	}

	public func remote(authorization _: ASAuthorization) async throws -> JWT {
		return .init(token: "", credentialID: Data())
	}

	public func remote(credentialRegistration _: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> JWT {
		return .init(token: "", credentialID: Data())
	}

	public func remote(credentialAssertion _: ASAuthorizationPublicKeyCredentialAssertion) async throws -> JWT {
		return .init(token: "", credentialID: Data())
	}

	public func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data) async throws -> Bool {
		return false
	}
}
