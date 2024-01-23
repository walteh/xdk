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

import XDKKeychain
import XDKSession
import XDKX

struct AssertionResult {
	let challenge: String
	let payload: String
	let assertion: String
}

public extension webauthn.devicecheck {
	enum Error: Swift.Error {
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
}

// public extension webauthn.devicecheck {
//	class Controller: NSObject, ObservableObject {
//		var cachedKey: Data?
//
//		@Published var ready = false
//
//		func setCachedKey(_ str: Data?) {
//			if str != nil, !str!.isEmpty {
//				self.cachedKey = str
//				self.ready = true
//			}
//		}
//
//		private let expapi: webauthn.API
//
//		init(api: webauthn.Client) {
//			self.expapi = api
//			super.init()
//
//
//
//			if abc != nil, !abc!.isEmpty {
//				self.setCachedKey(abc)
//			} else {
//				Task {
//					do {
//						try await attest()
//
//					} catch {
//						x.Error.Log(error, "attest failed")
//					}
//				}
//			}
//		}
//	}
// }

extension keychain.Key {
	static let AppAttestKey = keychain.Key(rawValue: "AppAttestKey")
}

extension webauthn.Client: webauthn.devicecheck.API {
	public func initialized() -> Bool {
		return keychainAPI.read(insecurly: "AppAttestKey").value != nil
	}

	public func assert(request: inout URLRequest, dataToSign: Data? = nil) async throws {
		guard let key = try keychainAPI.read(insecurly: "AppAttestKey").get() else {
			throw webauthn.devicecheck.Error.unexpectedNil
		}

		let challenge = try await Init(sessionID: sessionAPI.ID().data, type: .Get, credentialID: key)

		// read they body of the request as bytes
		guard let body = dataToSign ?? request.httpBody else {
			throw webauthn.devicecheck.Error.unexpectedNil
		}

		var combo = Data(body)

		combo.append(challenge)

		do {
			let assertion = try await DCAppAttestService.shared.generateAssertion(key.base64EncodedString(), clientDataHash: Data(combo).sha2())

			let headers = buildHeadersFor(requestAssertion: assertion, challenge: challenge, sessionID: sessionAPI.ID().data, credentialID: key)

			for (key, value) in headers {
				request.setValue(value, forHTTPHeaderField: key)
			}
		} catch {
			throw x.Error.Wrap(error, "DCAppAttestService.shared.generateAssertion failed")
		}
	}

	public func attest() async throws {
		let sessionID = sessionAPI.ID().data

		let ceremony: webauthn.CeremonyType = .Create

		let challenge = try await Init(sessionID: sessionID, type: ceremony)

		let key = try await DCAppAttestService.shared.generateKey()

		guard let datakey = key.base64Decoded else {
			throw x.error("DCAppAttestSerivice.shared.generateKey() returned a non base64 value")
				.with(key: "value", key)
				.log()
		}

		let clientDataJSON = #"{"challenge":""# + challenge.base64URLEncodedString() + #"","origin":"https://nugg.xyz","type":""# + ceremony.rawValue + #""}"#

		let attestation = try await DCAppAttestService.shared.attestKey(key, clientDataHash: clientDataJSON.data.sha2())

		let successfulAttest = try await remote(deviceAttestation: attestation, clientDataJSON: clientDataJSON, using: datakey, sessionID: sessionID)

		if successfulAttest {
			_ = keychainAPI.write(insecurly: "AppAttestKey", overwriting: true, as: datakey)
		} else {
			throw x.error("deviceAttestation was not successful").log()
		}
	}
}
