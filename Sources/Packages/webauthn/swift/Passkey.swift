//
//  Passkey.swift
//  nugg.xyz
//
//  Created by walter on 11/19/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import AuthenticationServices
import Foundation
import os

import XDKKeychain
import XDKX

public extension NSNotification.Name {
	static let UserSignedIn = Notification.Name("UserSignedInNotification")
	static let ModalSignInSheetCanceled = Notification.Name("ModalSignInSheetCanceledNotification")
	static let AssertRandomData = Notification.Name("AssertRandomDataNotification")

	static let UserSignInRequest = Notification.Name("UserSignInRequestNotification")
	static let PasskeyCredentialUpdated = Notification.Name("PasskeyCredentialUpdated")
}

// public extension webauthn.passkey {
//	class Controller: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
//		@Published public var credentialID: Data?
//
//		var isPerformingModalRequest = false
//
//		private var signInObserver: NSObjectProtocol?
//
//		private var expapi: webauthn.API
//
//		init(api: webauthn.Api) {
//			self.expapi = api
//
//			let r2 = api.keychainManager
//
//			if r2 != nil, !r2!.isEmpty {
//				self.credentialID = r2
//			}
//			super.init()
//
//
//		}
//	}
// }

class PasskeyCredentialID: NSObject, NSSecureCoding {
	static var supportsSecureCoding = true

	let credentialID: Data

	init(credentialID: Data) {
		self.credentialID = credentialID
	}

	public func encode(with coder: NSCoder) {
		coder.encode(credentialID, forKey: "credentialID")
	}

	required public init?(coder: NSCoder) {
		self.credentialID = coder.decodeObject(forKey: "credentialID") as! Data
	}
}

extension keychain.Key {
	static let PasskeyCredentialID = keychain.Key(rawValue: "PasskeyCredentialID")
}

extension webauthn.Client: webauthn.passkey.API {
	private static var _publicKeyProvider: ASAuthorizationPlatformPublicKeyCredentialProvider = .init(relyingPartyIdentifier: "nugg.xyz")

	public var publicKeyProvider: ASAuthorizationPlatformPublicKeyCredentialProvider {
		webauthn.Client._publicKeyProvider
	}

	private static var _isPerformingModalRequest: Bool = false

	public var isPerformingModalRequest: Bool {
		get {
			return webauthn.Client._isPerformingModalRequest
		}
		set(newValue) {
			webauthn.Client._isPerformingModalRequest = newValue
		}
	}

	public func startSignInObserver() -> NSObjectProtocol {
		let signInObserver = NotificationCenter.default.addObserver(forName: .UserSignInRequest, object: nil, queue: nil) { _ in
			Task.detached(priority: .userInitiated) {
				let _read = self.keychainAPI.read(objectType: PasskeyCredentialID.self, id: "default")
				guard let read = _read.value else {
					x.Error.Log(_read.error!, "")
					return
				}
				do {
					if read != nil {
						try await self.attestPasskey()
					} else {
						try await self.assertPasskey()
					}
				} catch {
					x.Error.Log(error, "")
				}
			}
		}

		return signInObserver
	}

	public func assertPasskey() async throws {
		guard let credid = try self.keychainAPI.read(objectType: PasskeyCredentialID.self, id: "default").get() else {
			throw x.Error.Wrap(webauthn.devicecheck.Error.invalidKey("credentialId"))
		}

		let challenge = try await Init(sessionID: sessionAPI.ID().data, type: .Get, credentialID: credid.credentialID)

		let req = publicKeyProvider.createCredentialAssertionRequest(challenge: challenge)

		req.allowedCredentials = [.init(credentialID: credid.credentialID)]

		let authController = ASAuthorizationController(authorizationRequests: [req])
		authController.delegate = self
		authController.presentationContextProvider = self
		authController.performRequests(options: .preferImmediatelyAvailableCredentials)
		isPerformingModalRequest = true
	}

	public func attestPasskey() async throws {
		let challenge = try await Init(sessionID: sessionAPI.ID().data, type: .Create)

		let registrationRequest = publicKeyProvider.createCredentialRegistrationRequest(
			challenge: challenge,
			name: "nugg.xyz",
			userID: sessionAPI.ID().data
		)

		let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
		authController.delegate = self
		authController.presentationContextProvider = self
		authController.performRequests(options: .preferImmediatelyAvailableCredentials)
		isPerformingModalRequest = true
	}

	public func authorizationController(
		controller _: ASAuthorizationController,
		didCompleteWithAuthorization authorization: ASAuthorization
	) {
		Task(priority: .high) {
			do {
				let res = try await remote(authorization: authorization)
				if let err = keychainAPI.write(object: PasskeyCredentialID(credentialID: res.credentialID), overwriting: true, id: "default") {
					throw err
				}
			} catch {
				x.Error.Log(error, "failed to successfully handle auth")
			}
		}
	}

	public func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
		guard let authorizationError = error as? ASAuthorizationError else {
			isPerformingModalRequest = false
			return
		}

		x.error(error, "webauthn error").log()

		if authorizationError.code == .canceled {
			if authorizationError.errorUserInfo["NSLocalizedFailureReason"] as? String == "No credentials available for login." {
				// this happens when the user tries to log in with a pass key they have deleted
//					self.credentialID = nil
				do {
					if let err = keychainAPI.write(object: PasskeyCredentialID(credentialID: Data()), overwriting: true, id: "default") {
						throw err
					}
				} catch {
					x.error(error).log()
				}
			}
		}

		isPerformingModalRequest = false
	}

	func didFinishSignIn() {
		NotificationCenter.default.post(name: .UserSignedIn, object: nil)
	}

	func didCancelModalSheet() {
		NotificationCenter.default.post(name: .ModalSignInSheetCanceled, object: nil)
	}

	public func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
		.init()
	}
}
