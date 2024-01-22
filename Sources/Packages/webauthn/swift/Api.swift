//
//  WebAuthnExpApi.swift
//  nugg.xyz
//
//  Created by walter on 11/12/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import AuthenticationServices
import Foundation

import hex_swift
import keychain_swift
import sdk_session
import x_swift

public extension webauthn {
	class Client: NSObject {
		let host: URL

		let sessionAPI: SESSION
		let keychainAPI: KEYCHAIN

		public init(host: String, keychainAPI: KEYCHAIN, sessionAPI: SESSION) {
			self.host = .init(string: host)!
			self.keychainAPI = keychainAPI
			self.sessionAPI = sessionAPI
			super.init()
		}
	}
}

extension webauthn.Client: webauthn.API {
	public func Init(sessionID: Data, type: webauthn.CeremonyType, credentialID: Data? = nil) async throws -> webauthn.Challenge {
		var req: URLRequest = .init(url: self.host.appending(path: "/init"))

		req.setValue(xhex.ToHexString(sessionID), forHTTPHeaderField: "X-Nugg-Hex-Session-ID")
		req.setValue(type.rawValue, forHTTPHeaderField: "X-Nugg-Utf-Ceremony-Type")

		if credentialID != nil {
			req.setValue(xhex.ToHexString(credentialID!), forHTTPHeaderField: "X-Nugg-Hex-Credential-ID")
		}

		req.httpMethod = "POST"

		let (_, response) = try await URLSession.shared.data(for: req)

		let chal = try checkFor(header: "x-nugg-hex-challenge", in: response, with: 204)

		return xhex.ToHexData(chal.data)
	}

	public func remote(authorization: ASAuthorization) async throws -> webauthn.JWT {
		if let reg1 = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
			return try await self.remote(credentialRegistration: reg1)
		} else if let reg2 = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion {
			return try await self.remote(credentialAssertion: reg2)
		}

		throw x.error("invalid authentication type")
	}

	func buildHeadersFor(requestAssertion assertion: Data, challenge: Data, sessionID: Data, credentialID: Data) -> [String: String] {
		var abc = """
		{
			"credential_id":"\(xhex.ToHexString(credentialID))",
			"assertion_object":"\(xhex.ToHexString(assertion))",
			"session_id":"\(xhex.ToHexString(sessionID))",
			"provider":"apple",
			"client_data_json":"{\\"challenge\\":\\"\(challenge.base64URLEncodedString())\\",\\"origin\\":\\"https://nugg.xyz\\",\\"type\\":\\"\(webauthn.CeremonyType.Get.rawValue)\\"}"
		}
		"""

		abc.removeAll { x in x.isNewline || x.isWhitespace }

		return ["X-Nugg-Hex-Request-Assertion": xhex.ToHexString(abc.data(using: .utf8) ?? Data())]
	}

	public func remote(credentialRegistration attest: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> webauthn.JWT {
		var req: URLRequest = .init(url: self.host.appending(path: "/ios/register/passkey"))

		req.httpMethod = "POST"

		guard let attester = attest.rawAttestationObject else {
			throw x.error("unexpected nil")
				.with(key: "variable", "attest.rawAttestationObject")
		}

		req.setValue(xhex.ToHexString(attest.credentialID), forHTTPHeaderField: "X-Nugg-Hex-Credential-Id")
		req.setValue(xhex.ToHexString(attester), forHTTPHeaderField: "X-Nugg-Hex-Attestation-Object")
		req.setValue(attest.rawClientDataJSON.string!, forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")

		try await self.assert(request: &req, dataToSign: attest.credentialID)

		let (_, response) = try await URLSession.shared.data(for: req)

		let chal = try checkFor(header: "x-nugg-utf-access-token", in: response, with: 204)

		return .init(token: chal, credentialID: attest.credentialID)
	}

	public func remote(credentialAssertion assert: ASAuthorizationPublicKeyCredentialAssertion) async throws -> webauthn.JWT {
		var req: URLRequest = .init(url: self.host.appending(path: "/passkey/assert"))

		req.httpMethod = "POST"

		req.setValue(xhex.ToHexString(assert.credentialID), forHTTPHeaderField: "X-Nugg-Hex-Credential-Id")
		req.setValue(xhex.ToHexString(assert.signature), forHTTPHeaderField: "X-Nugg-Hex-Signature")
		req.setValue(assert.rawClientDataJSON.utfEncodedString(), forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")
		req.setValue(xhex.ToHexString(assert.userID), forHTTPHeaderField: "X-Nugg-Hex-User-Id")
		req.setValue(xhex.ToHexString(assert.rawAuthenticatorData), forHTTPHeaderField: "X-Nugg-Hex-Authenticator-Data")
		req.setValue("public-key", forHTTPHeaderField: "X-Nugg-Utf-Credential-Type")

		let (_, response) = try await URLSession.shared.data(for: req)

		let chal = try checkFor(header: "x-nugg-utf-access-token", in: response, with: 204)

		return .init(token: chal, credentialID: assert.credentialID)
	}

	public func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data, sessionID: Data) async throws -> Bool {
		var req: URLRequest = .init(url: self.host.appending(path: "/ios/register/device"))

		req.httpMethod = "POST"

		req.setValue(xhex.ToHexString(key), forHTTPHeaderField: "X-Nugg-Hex-Attestation-Key")
		req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
//		req.setValue(da.base64URLEncodedString(), forHTTPHeaderField: "X-Nugg-Base64-Attestation-Object")
		req.setValue(clientDataJSON, forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")
		req.setValue(xhex.ToHexString(sessionID), forHTTPHeaderField: "X-Nugg-Hex-Session-Id")

		req.httpBodyStream = .init(data: xhex.ToHexString(da).data(using: .utf8) ?? Data())

		let (_, response) = try await URLSession.shared.data(for: req)

		let res = try format(ashttp: response)

		print(res.debugDescription)

		return res.statusCode == 204
	}
}

func format(ashttp: URLResponse) throws -> HTTPURLResponse {
	guard let httpResponse = ashttp as? HTTPURLResponse else {
		throw x.error("unexpected nil")
	}
	return httpResponse
}

func checkFor(header: String = "", in response: URLResponse, with _: Int) throws -> String {
	let httpResponse = try format(ashttp: response)

	if httpResponse.statusCode != 204 {
		throw x.error("status code not 204")
			.with(key: "statusCode", "\(httpResponse.statusCode)")
			.with(key: "lookingForHeader", header)
			.with(key: "response:debugDescription", response.debugDescription)
	}

	if header == "" { return "" }

	guard let xNuggChallenge = httpResponse.allHeaderFields[header.lowercased()] as? String else {
		throw x.error("invalid http response")
			.with(key: "header_name", header.lowercased())
			.with(key: "headers", httpResponse.allHeaderFields.debugDescription)
	}

	if xNuggChallenge == "" {
		throw x.error("invalid http response")
			.with(message: "value of \(header.lowercased()) header is empty string")
	}

	return xNuggChallenge
}
