//
//  RemoteAPI.swift
//  nugg.xyz
//
//  Created by walter on 11/12/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import AuthenticationServices
import Foundation

import XDKAppSession
import XDKHex
import XDKKeychain
import XDKX
import XDKXID

extension WebauthnAuthenticationServicesClient: WebauthnRemoteAPI {
	public func remote(init type: CeremonyType, credentialID: Data? = nil) async throws -> Challenge {
		var req: URLRequest = .init(url: host.appending(path: "/init"))

		req.setValue(xhex.ToHexString(sessionAPI.ID().utf8()), forHTTPHeaderField: "X-Nugg-Hex-Session-ID")
		req.setValue(type.rawValue, forHTTPHeaderField: "X-Nugg-Utf-Ceremony-Type")

		if credentialID != nil {
			req.setValue(xhex.ToHexString(credentialID!), forHTTPHeaderField: "X-Nugg-Hex-Credential-ID")
		}

		req.httpMethod = "POST"

		let (_, response) = try await URLSession.shared.data(for: req)

		let chal = try checkFor(header: "x-nugg-hex-challenge", in: response, with: 204)

		return try XID.rebuild(string: chal)
	}

	public func remote(authorization: ASAuthorization) async throws -> JWT {
		if let reg1 = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
			return try await self.remote(credentialRegistration: reg1)
		} else if let reg2 = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion {
			return try await self.remote(credentialAssertion: reg2)
		}

		throw x.error("invalid authentication type")
	}

	public func remote(credentialRegistration attest: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> JWT {
		var req: URLRequest = .init(url: host.appending(path: "/ios/register/passkey"))

		req.httpMethod = "POST"

		guard let attester = attest.rawAttestationObject else {
			throw x.error("unexpected nil").event { $0.add("variable", "attest.rawAttestationObject") }
		}

		req.setValue(xhex.ToHexString(attest.credentialID), forHTTPHeaderField: "X-Nugg-Hex-Credential-Id")
		req.setValue(xhex.ToHexString(attester), forHTTPHeaderField: "X-Nugg-Hex-Attestation-Object")
		req.setValue(attest.rawClientDataJSON.string!, forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")

		try await assert(request: &req, dataToSign: attest.credentialID)

		let (_, response) = try await URLSession.shared.data(for: req)

		let chal = try checkFor(header: "x-nugg-utf-access-token", in: response, with: 204)

		return .init(token: chal, credentialID: attest.credentialID)
	}

	public func remote(credentialAssertion assert: ASAuthorizationPublicKeyCredentialAssertion) async throws -> JWT {
		var req: URLRequest = .init(url: host.appending(path: "/passkey/assert"))

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

	func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data) async throws -> Bool {
		var req: URLRequest = .init(url: host.appending(path: "/ios/register/device"))

		req.httpMethod = "POST"

		req.setValue(xhex.ToHexString(key), forHTTPHeaderField: "X-Nugg-Hex-Attestation-Key")
		req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
//		req.setValue(da.base64URLEncodedString(), forHTTPHeaderField: "X-Nugg-Base64-Attestation-Object")
		req.setValue(clientDataJSON, forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")
		req.setValue(xhex.ToHexString(sessionAPI.ID().utf8()), forHTTPHeaderField: "X-Nugg-Hex-Session-Id")

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
		throw x.error("status code not 204").event {
			$0.add("statusCode", "\(httpResponse.statusCode)")
				.add("lookingForHeader", header)
				.add("response:debugDescription", response.debugDescription)
		}
	}

	if header == "" { return "" }

	guard let xNuggChallenge = httpResponse.allHeaderFields[header.lowercased()] as? String else {
		throw x.error("invalid http response").event {
			$0.add("header_name", header.lowercased())
				.add("headers", httpResponse.allHeaderFields.debugDescription)
		}
	}

	if xNuggChallenge == "" {
		throw x.error("invalid http response: value of \(header.lowercased()) header is empty string")
	}

	return xNuggChallenge
}

func buildHeadersFor(requestAssertion assertion: Data, challenge: XDKXID.XID, sessionID: XDKXID.XID, credentialID: Data) -> [String: String] {
	var abc = """
	{
		"credential_id":"\(xhex.ToHexString(credentialID))",
		"assertion_object":"\(xhex.ToHexString(assertion))",
		"session_id":"\(xhex.ToHexString(sessionID.utf8()))",
		"provider":"apple",
		"client_data_json":"{\\"challenge\\":\\"\(challenge.utf8().base64URLEncodedString())\\",\\"origin\\":\\"https://nugg.xyz\\",\\"type\\":\\"\(CeremonyType.Get.rawValue)\\"}"
	}
	"""

	abc.removeAll { x in x.isNewline || x.isWhitespace }

	return ["X-Nugg-Hex-Request-Assertion": xhex.ToHexString(abc.data(using: .utf8) ?? Data())]
}
