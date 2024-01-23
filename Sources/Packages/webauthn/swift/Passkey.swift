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

class PasskeyCredentialID: NSObject, NSSecureCoding {
	static var supportsSecureCoding = true

	let credentialID: Data

	init(credentialID: Data) {
		self.credentialID = credentialID
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.credentialID, forKey: "credentialID")
	}

	public required init?(coder: NSCoder) {
		self.credentialID = coder.decodeObject(forKey: "credentialID") as! Data
	}
}


extension WebauthnAuthenticationServicesClient: WebauthnPasskeyAPI {

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
			throw x.Error.Wrap(DeviceCheckError.invalidKey("credentialId"))
		}

		let challenge = try await remote(init: .Get, credentialID: credid.credentialID)

		let req = self.publicKeyProvider.createCredentialAssertionRequest(challenge: challenge.data())

		req.allowedCredentials = [.init(credentialID: credid.credentialID)]

		let authController = ASAuthorizationController(authorizationRequests: [req])
		authController.delegate = self
		authController.presentationContextProvider = self
		authController.performRequests(options: .preferImmediatelyAvailableCredentials)
		self.isPerformingModalRequest = true
	}

	public func attestPasskey() async throws {
		let challenge = try await remote(init: .Create)

		let registrationRequest = self.publicKeyProvider.createCredentialRegistrationRequest(
			challenge: challenge.data(),
			name: "nugg.xyz",
			userID: sessionAPI.ID().data()
		)

		let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
		authController.delegate = self
		authController.presentationContextProvider = self
		authController.performRequests(options: .preferImmediatelyAvailableCredentials)
		self.isPerformingModalRequest = true
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
			self.isPerformingModalRequest = false
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

		self.isPerformingModalRequest = false
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
