//
//  File.swift
//
//
//  Created by walter on 3/5/23.
//

import AuthenticationServices
import Foundation

public class WebauthnNoopAPI: webauthn.API {
	public init() {}

	public func Init(sessionID _: Data, type _: webauthn.CeremonyType, credentialID _: Data?) async throws -> webauthn.Challenge {
		return Data()
	}

	public func remote(authorization _: ASAuthorization) async throws -> webauthn.JWT {
		return .init(token: "", credentialID: Data())
	}

	public func remote(credentialRegistration _: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> webauthn.JWT {
		return .init(token: "", credentialID: Data())
	}

	public func remote(credentialAssertion _: ASAuthorizationPublicKeyCredentialAssertion) async throws -> webauthn.JWT {
		return .init(token: "", credentialID: Data())
	}

	public func remote(deviceAttestation _: Data, clientDataJSON _: String, using _: Data, sessionID _: Data) async throws -> Bool {
		return false
	}
}
