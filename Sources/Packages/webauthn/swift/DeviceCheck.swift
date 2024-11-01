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

import Err

import XDK

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

struct AppAttestKeyID: Codable, Sendable {
	let keyID: Data

	init(keyID: Data) {
		self.keyID = keyID
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.keyID, forKey: "keyID")
	}

	public init?(coder: NSCoder) {
		self.keyID = coder.decodeObject(forKey: "keyID") as! Data
	}
}

extension WebauthnAuthenticationServicesClient: WebauthnDeviceCheckAPI {
	public func initialized() -> Result<Bool, Error> {
		return XDK.Read(using: self.keychainAPI, AppAttestKeyID.self).map { res in return res != nil }
	}

	@err public func assert(request: URLRequest , dataToSign: Data? = nil) async -> Result<[String: String], Error> {


		guard let key = XDK.Read(using: self.keychainAPI, AppAttestKeyID.self).get() else {
			return .failure(x.error("failed to read key from keychain", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		guard let key else {
			return .failure(x.error("failed to read key from keychain", alias: DeviceCheckError.unexpectedNil))
		}

		guard let challenge = await self.remote(init: .Get, credentialID: key.keyID).get() else {
			return .failure(x.error("failed to get challenge", root: err, alias: DeviceCheckError.unexpectedNil))
		}

		// read they body of the request as bytes
		if dataToSign == nil && nil == request.httpBody {
			return .failure(x.error("failed to get body of request", alias: DeviceCheckError.unexpectedNil))
		}

		var combo = Data(dataToSign ?? request.httpBody!)

		combo.append(challenge.utf8())

		let safeCombo = combo

		guard let assertion = try await DCAppAttestService.shared.generateAssertion(key.keyID.base64EncodedString(), clientDataHash: Data(safeCombo).sha2()) else {
			return .failure(x.error("DCAppAttestService.shared.generateAssertion failed", root: err))
		}

		let headers = buildHeadersFor(requestAssertion: assertion, challenge: challenge, sessionID: sessionAPI.ID(), credentialID: key.keyID)


		return .success(headers)
	}

	@err public func attest() async -> Result<Void, Error> {
		let ceremony: CeremonyType = .Create

		guard let challenge = await self.remote(init: ceremony).get() else {
			return .failure(x.error("failed to get challenge", root: err))
		}

		guard let key = try await DCAppAttestService.shared.generateKey() else {
			return .failure(x.error("DCAppAttestSerivice.shared.generateKey() failed", root: err))
		}

		guard let datakey = key.base64Decoded else {
			return .failure(x.error("DCAppAttestSerivice.shared.generateKey() returned a non base64 value").event {
				$0.add("value", key)
			})
		}

		let clientDataJSON = #"{"challenge":""# + challenge.utf8().base64URLEncodedString() + #"","origin":"https://nugg.xyz","type":""# + ceremony.rawValue + #""}"#

		guard let attestation = try await DCAppAttestService.shared.attestKey(key, clientDataHash: clientDataJSON.data.sha2()) else {
			return .failure(x.error("DCAppAttestService.shared.attestKey failed", root: err))
		}

		guard let _ = await self.remote(deviceAttestation: attestation, clientDataJSON: clientDataJSON, using: datakey).get() else {
			return .failure(x.error("remote(deviceAttestation:clientDataJSON:using:) failed", root: err))
		}

		guard let _ =  XDK.Write(using: self.keychainAPI, AppAttestKeyID(keyID: datakey)).get() else {
			return .failure(x.error("failed to write key to keychain", root: err))
		}

		return .success(())
	}
}
