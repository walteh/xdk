//
//  RemoteAPI.swift
//  nugg.xyz
//
//  Created by walter on 11/12/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import AuthenticationServices
import Foundation
import Err

import XDK
import XDKHex
import XDKKeychain

extension WebauthnAuthenticationServicesClient: WebauthnRemoteAPI {
	@err public func remote(init type: CeremonyType, credentialID: Data? = nil) async -> Result<Challenge, Error> {
		var req: URLRequest = .init(url: host.appending(path: "/init"))

		req.setValue(xhex.ToHexString(sessionAPI.ID().utf8()), forHTTPHeaderField: "X-Nugg-Hex-Session-ID")
		req.setValue(type.rawValue, forHTTPHeaderField: "X-Nugg-Utf-Ceremony-Type")

		if credentialID != nil {
			req.setValue(xhex.ToHexString(credentialID!), forHTTPHeaderField: "X-Nugg-Hex-Credential-ID")
		}

		req.httpMethod = "POST"

		let safeReq = req

		guard let (_, response) = try await URLSession.shared.data(for: safeReq) else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let chal = checkFor(header: "x-nugg-hex-challenge", in: response, with: 204).get() else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let res = XDK.XID.rebuild(string: chal).get() else {
			return .failure(XDK.Err("failed to rebuild challenge", root: err, alias: DeviceCheckError.invalidChallenge))
		}

		return .success(res)
	}

	public func remote(authorization: ASAuthorization) async -> Result<JWT, Error> {
		if let reg1 = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
			return await self.remote(credentialRegistration: reg1)
		} else if let reg2 = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion {
			return await self.remote(credentialAssertion: reg2)
		}

		return .failure(XDK.Err("unexpected nil").event { $0.add("variable", "authorization.credential") })
	}

	@err public func remote(credentialRegistration attest: ASAuthorizationPlatformPublicKeyCredentialRegistration) async -> Result<JWT, Error> {


		var req: URLRequest = .init(url: host.appending(path: "/ios/register/passkey"))

		req.httpMethod = "POST"

		guard let attester = attest.rawAttestationObject else {
			return .failure(XDK.Err("unexpected nil").event { $0.add("variable", "attest.rawAttestationObject") })
		}

		req.setValue(xhex.ToHexString(attest.credentialID), forHTTPHeaderField: "X-Nugg-Hex-Credential-Id")
		req.setValue(xhex.ToHexString(attester), forHTTPHeaderField: "X-Nugg-Hex-Attestation-Object")
		req.setValue(attest.rawClientDataJSON.string!, forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")

		guard let safeReqHeaders = await self.assert(request: req, dataToSign: attest.credentialID).get() [req] else {
			return .failure(XDK.Err("failed to assert", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		req.allHTTPHeaderFields = safeReqHeaders

		guard let (_, rez) = try await URLSession.shared.data(for: req) [req] else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let chal = checkFor(header: "x-nugg-utf-access-token", in: rez, with: 204).get() else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		return .success(.init(token: chal, credentialID: attest.credentialID))
	}

	@err public func remote(credentialAssertion assert: ASAuthorizationPublicKeyCredentialAssertion) async -> Result<JWT, Error> {
		var req: URLRequest = .init(url: host.appending(path: "/passkey/assert"))

		req.httpMethod = "POST"

		req.setValue(xhex.ToHexString(assert.credentialID), forHTTPHeaderField: "X-Nugg-Hex-Credential-Id")
		req.setValue(xhex.ToHexString(assert.signature), forHTTPHeaderField: "X-Nugg-Hex-Signature")
		req.setValue(assert.rawClientDataJSON.utfEncodedString(), forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")
		req.setValue(xhex.ToHexString(assert.userID), forHTTPHeaderField: "X-Nugg-Hex-User-Id")
		req.setValue(xhex.ToHexString(assert.rawAuthenticatorData), forHTTPHeaderField: "X-Nugg-Hex-Authenticator-Data")
		req.setValue("public-key", forHTTPHeaderField: "X-Nugg-Utf-Credential-Type")

		let safeReq = req

		guard let (_, response) =  try await URLSession.shared.data(for: safeReq) else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let chal = checkFor(header: "x-nugg-utf-access-token", in: response, with: 204).get() else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		return .success(.init(token: chal, credentialID: assert.credentialID))
	}

	@err func remote(deviceAttestation da: Data, clientDataJSON: String, using key: Data) async -> Result<Void, Error> {


		var req: URLRequest = .init(url: host.appending(path: "/ios/register/device"))

		req.httpMethod = "POST"

		req.setValue(xhex.ToHexString(key), forHTTPHeaderField: "X-Nugg-Hex-Attestation-Key")
		req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
//		req.setValue(da.base64URLEncodedString(), forHTTPHeaderField: "X-Nugg-Base64-Attestation-Object")
		req.setValue(clientDataJSON, forHTTPHeaderField: "X-Nugg-Utf-Client-Data-Json")
		req.setValue(xhex.ToHexString(sessionAPI.ID().utf8()), forHTTPHeaderField: "X-Nugg-Hex-Session-Id")

		req.httpBodyStream = .init(data: xhex.ToHexString(da).data(using: .utf8) ?? Data())

		let safeReq = req

		guard let (_, response) = try await URLSession.shared.data(for: safeReq) else {
			return .failure(XDK.Err("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let res = response as? HTTPURLResponse else {
			return .failure(XDK.Err("failed to get challenge", alias: DeviceCheckError.unexpectedNil))
		}

		if res.statusCode != 204 {
			return .failure(XDK.Err("status code not 204").event {
				$0.add("statusCode", "\(res.statusCode)")
					.add("response:debugDescription", response.debugDescription)
			})
		}

		return .success(())
	}
}

func checkFor(header: String = "", in response: URLResponse, with _: Int) -> Result<String, Error> {
	guard let httpResponse = response as? HTTPURLResponse else {
		return .failure(XDK.Err("failed to get challenge").event {
			$0.add("response:debugDescription", response.debugDescription)
		})
	}

	if httpResponse.statusCode != 204 {
		return .failure(XDK.Err("status code not 204").event {
			$0.add("statusCode", "\(httpResponse.statusCode)")
				.add("lookingForHeader", header)
				.add("response:debugDescription", response.debugDescription)
		})
	}

	if header == "" { return .success("") }

	guard let xNuggChallenge = httpResponse.allHeaderFields[header.lowercased()] as? String else {
		return .failure(XDK.Err("invalid http response").event {
			$0.add("header_name", header.lowercased())
				.add("headers", httpResponse.allHeaderFields.debugDescription)
		})
	}

	if xNuggChallenge == "" {
		return .failure(XDK.Err("invalid http response: value of \(header.lowercased()) header is empty string"))
	}

	return .success(xNuggChallenge)
}

func buildHeadersFor(requestAssertion assertion: Data, challenge: XDK.XID, sessionID: XDK.XID, credentialID: Data) -> [String: String] {
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
