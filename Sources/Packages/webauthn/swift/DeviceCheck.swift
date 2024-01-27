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

import XDK
import XDKAppSession

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
	public func initialized() -> Result<Bool, Error> {
		return XDK.Read(using: self.keychainAPI, AppAttestKeyID.self).map { res in return res != nil }
	}

	public func assert(request: inout URLRequest, dataToSign: Data? = nil) async -> Result<Void, Error> {
		var err: Error? = nil

		guard let key = XDK.Read(using: self.keychainAPI, AppAttestKeyID.self).to(&err) else {
			return .failure(x.error("failed to read key from keychain", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let key else {
			return .failure(x.error("failed to read key from keychain", alias: DeviceCheckError.unexpectedNil))
		}

		guard let challenge = await remote(init: .Get, credentialID: key.keyID).to(&err) else {
			return .failure(x.error("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		// read they body of the request as bytes
		guard let body = dataToSign ?? request.httpBody else {
			return .failure(x.error("failed to get body of request", alias: DeviceCheckError.unexpectedNil))
		}

		var combo = Data(body)

		combo.append(challenge.utf8())

		let safeCombo = combo

		guard let assertion = await Result.X({ try await DCAppAttestService.shared.generateAssertion(key.keyID.base64EncodedString(), clientDataHash: Data(safeCombo).sha2()) }).to(&err) else {
			return .failure(x.error("DCAppAttestService.shared.generateAssertion failed", root: err))
		}

		let headers = buildHeadersFor(requestAssertion: assertion, challenge: challenge, sessionID: sessionAPI.ID(), credentialID: key.keyID)

		for (key, value) in headers {
			request.setValue(value, forHTTPHeaderField: key)
		}

		return .success(())
	}

	public func attest() async -> Result<Void, Error> {
		var err: Error? = nil

		let ceremony: CeremonyType = .Create

		guard let challenge = await self.remote(init: ceremony).to(&err) else {
			return .failure(x.error("failed to get challenge", root: err))
		}

		guard let key = await Result.X({ try await DCAppAttestService.shared.generateKey() }).to(&err) else {
			return .failure(x.error("DCAppAttestSerivice.shared.generateKey() failed", root: err))
		}

		guard let datakey = key.base64Decoded else {
			return .failure(x.error("DCAppAttestSerivice.shared.generateKey() returned a non base64 value").event {
				$0.add("value", key)
			})
		}

		let clientDataJSON = #"{"challenge":""# + challenge.utf8().base64URLEncodedString() + #"","origin":"https://nugg.xyz","type":""# + ceremony.rawValue + #""}"#

		guard let attestation = await Result.X({
			try await DCAppAttestService.shared.attestKey(key, clientDataHash: clientDataJSON.data.sha2())
		}).to(&err) else {
			return .failure(x.error("DCAppAttestService.shared.attestKey failed", root: err))
		}

		guard let _ = await self.remote(deviceAttestation: attestation, clientDataJSON: clientDataJSON, using: datakey).to(&err) else {
			return .failure(x.error("remote(deviceAttestation:clientDataJSON:using:) failed", root: err))
		}

		if let _ = XDK.Write(using: self.keychainAPI, AppAttestKeyID(keyID: datakey)).to(&err) {
			return .failure(x.error("failed to write key to keychain", root: err))
		}

		return .success(())
	}
}
