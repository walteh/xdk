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

import XDK
import XDKKeychain

public extension NSNotification.Name {
	static let UserSignedIn = Notification.Name("UserSignedInNotification")
	static let ModalSignInSheetCanceled = Notification.Name("ModalSignInSheetCanceledNotification")
	static let AssertRandomData = Notification.Name("AssertRandomDataNotification")

	static let UserSignInRequest = Notification.Name("UserSignInRequestNotification")
	static let PasskeyCredentialUpdated = Notification.Name("PasskeyCredentialUpdated")
}

class PasskeyCredentialID: NSObject, NSSecureCoding {
	static let supportsSecureCoding = true

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
				var err = Error?.none
				guard let read = XDK.Read(using: self.keychainAPI, PasskeyCredentialID.self).to(&err) else {
					x.log(.critical).err(err).send("webauthn error")
					return
				}
				if read != nil {
					guard let _ = await self.attestPasskey().to(&err) else {
						x.log(.critical).err(err).send("webauthn error in attest")
						return
					}
				} else {
					guard let _ = await self.assertPasskey().to(&err) else {
						x.log(.critical).err(err).send("webauthn error in assert")
						return
					}
				}
			}
		}

		return signInObserver
	}

@MainActor
	public func assertPasskey() async -> Result<Void, Error> {
		var err = Error?.none

		guard let credid = XDK.Read(using: self.keychainAPI, PasskeyCredentialID.self).to(&err) else {
			return .failure(x.error("cound not assert", root: err, alias: DeviceCheckError.invalidKey("credentialId")))
		}

		guard let credid else {
			return .failure(x.error("cound not assert because credentialId is nil", alias: DeviceCheckError.invalidKey("credentialId")))
		}

		guard let challenge = await remote(init: .Get, credentialID: credid.credentialID).to(&err) else {
			return .failure(x.error("cound not assert", root: err, alias: DeviceCheckError.invalidKey("challenge")))
		}

		let req = self.publicKeyProvider.createCredentialAssertionRequest(challenge: challenge.utf8())

		req.allowedCredentials = [.init(credentialID: credid.credentialID)]

		let authController = ASAuthorizationController(authorizationRequests: [req])
		authController.delegate = self
		authController.presentationContextProvider = self
		authController.performRequests(options: .preferImmediatelyAvailableCredentials)
		// self.isPerformingModalRequest = true

		return .success(())
	}

@MainActor
	public func attestPasskey() async -> Result<Void, Error> {
		var err = Error?.none

		guard let challenge = await remote(init: .Create).to(&err) else {
			return .failure(x.error("probelm getting challenge", root: err))
		}

		let registrationRequest = self.publicKeyProvider.createCredentialRegistrationRequest(
			challenge: challenge.utf8(),
			name: "nugg.xyz",
			userID: sessionAPI.ID().utf8()
		)

		let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
		authController.delegate = self
		authController.presentationContextProvider = self
		authController.performRequests(options: .preferImmediatelyAvailableCredentials)
		// self.isPerformingModalRequest = true

		return .success(())
	}


	public func authorizationController(
		controller _: ASAuthorizationController,
		didCompleteWithAuthorization authorization: ASAuthorization
	) {
		Task(priority: .high) {
			var err = Error?.none
			guard let res = await remote(authorization: authorization).to(&err) else {
				XDK.Log(.critical).err(err).send("failed to successfully handle auth")
				return
			}
			guard let _ = XDK.Write(using: self.keychainAPI, PasskeyCredentialID(credentialID: res.credentialID)).to(&err) else {
				XDK.Log(.critical).err(err).send("failed to write credential id")
				return
			}
		}
	}


	public func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
		guard let authorizationError = error as? ASAuthorizationError else {
			// self.isPerformingModalRequest = false
			return
		}

		x.log(.error).err(error).send("webauthn error")

		if authorizationError.code == .canceled {
			if authorizationError.errorUserInfo["NSLocalizedFailureReason"] as? String == "No credentials available for login." {
				// this happens when the user tries to log in with a pass key they have deleted
//					self.credentialID = nil
				var err = Error?.none
				guard let _ = XDK.Write(using: self.keychainAPI, PasskeyCredentialID(credentialID: Data())).to(&err) else {
					XDK.Log(.critical).err(err).send("failed to write credential id")
					return
				}
			}
		}

		// self.isPerformingModalRequest = false
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
