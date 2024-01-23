//
//  DeviceCheck.swift
//  nugg.xyz
//
//  Created by walter on 11/19/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import AuthenticationServices
import CryptoKit
import DeviceCheck
import Foundation
import os

import XDKAppSession
import XDKKeychain
import XDKX

struct AssertionResult {
	let challenge: String
	let payload: String
	let assertion: String
}

enum DeviceCheckError: Swift.Error {
	case invalidKey(String)
	case invalidKeySize(Int)
	case invalidKeyData(String)
	case attestFailed
	case assertionFailed
	case invalidAssertion
	case invalidChallenge
	case invalidPayload
	case invalidSignature
	case unexpectedNil
}

class AppAttestKeyID: NSObject, NSSecureCoding {
	static var supportsSecureCoding = true

	let keyID: Data

	init(keyID: Data) {
		self.keyID = keyID
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.keyID, forKey: "keyID")
	}

	public required init?(coder: NSCoder) {
		self.keyID = coder.decodeObject(forKey: "keyID") as! Data
	}
}

extension WebauthnAuthenticationServicesClient: WebauthnDeviceCheckAPI {
	public func initialized() throws -> Bool {
		return try self.keychainAPI.read(objectType: AppAttestKeyID.self, id: "default").get() != nil
	}

	public func assert(request: inout URLRequest, dataToSign: Data? = nil) async throws {
		guard let key = try self.keychainAPI.read(objectType: AppAttestKeyID.self, id: "default").get() else {
			throw DeviceCheckError.unexpectedNil
		}

		let challenge = try await remote(init: .Get, credentialID: key.keyID)

		// read they body of the request as bytes
		guard let body = dataToSign ?? request.httpBody else {
			throw DeviceCheckError.unexpectedNil
		}

		var combo = Data(body)

		combo.append(challenge.data())

		do {
			let assertion = try await DCAppAttestService.shared.generateAssertion(key.keyID.base64EncodedString(), clientDataHash: Data(combo).sha2())

			let headers = buildHeadersFor(requestAssertion: assertion, challenge: challenge, sessionID: sessionAPI.ID(), credentialID: key.keyID)

			for (key, value) in headers {
				request.setValue(value, forHTTPHeaderField: key)
			}
		} catch {
			throw x.Error.Wrap(error, "DCAppAttestService.shared.generateAssertion failed")
		}
	}

	public func attest() async throws {
		let ceremony: CeremonyType = .Create

		let challenge = try await remote(init: ceremony)

		let key = try await DCAppAttestService.shared.generateKey()

		guard let datakey = key.base64Decoded else {
			throw x.error("DCAppAttestSerivice.shared.generateKey() returned a non base64 value")
				.with(key: "value", key)
				.log()
		}

		let clientDataJSON = #"{"challenge":""# + challenge.data().base64URLEncodedString() + #"","origin":"https://nugg.xyz","type":""# + ceremony.rawValue + #""}"#

		let attestation = try await DCAppAttestService.shared.attestKey(key, clientDataHash: clientDataJSON.data.sha2())

		let successfulAttest = try await remote(deviceAttestation: attestation, clientDataJSON: clientDataJSON, using: datakey)

		if successfulAttest {
			if let err = keychainAPI.write(object: AppAttestKeyID(keyID: datakey), overwriting: true, id: "default") {
				throw err
			}
		} else {
			throw x.error("deviceAttestation was not successful").log()
		}
	}
}
