//
//  AccessToken.swift
//
//  Created by walter on 1/29/24.
//

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK

public struct UserSignInData: Equatable {
	public let activationURL: URL
	public let activationURLWithCode: URL
	public let code: String

	static func fromAWS(_ input: AWSSSOOIDC.StartDeviceAuthorizationOutput) -> UserSignInData {
		return UserSignInData(
			activationURL: URL(string: input.verificationUri!)!,
			activationURLWithCode: URL(string: input.verificationUriComplete!)!,
			code: input.deviceCode!
		)
	}
}

public protocol AccessToken {
	var accessToken: String { get }
	var refreshToken: String { get }
	var expiresAt: Date { get }
	var region: String { get }
	var startURL: URL { get }
}

public class SecureAWSSSOAccessToken: NSObject, NSSecureCoding {
	public static var supportsSecureCoding: Bool = true

	public let accessToken: String
	public let refreshToken: String
	public let expiresAt: Date
	public let region: String
	public let startURL: URL

	init(accessToken: String, refreshToken: String, expiresAt: Date, region: String, startURL: URL) {
		self.accessToken = accessToken
		self.refreshToken = refreshToken
		self.expiresAt = expiresAt
		self.region = region
		self.startURL = startURL
	}

	// MARK: - NSSecureCoding

	public required init?(coder: NSCoder) {
		guard let accessToken = coder.decodeObject(of: NSString.self, forKey: "accessToken") as String?,
		      let refreshToken = coder.decodeObject(of: NSString.self, forKey: "refreshToken") as String?,
		      let startURL = coder.decodeObject(of: NSURL.self, forKey: "startURL") as URL?,
		      let region = coder.decodeObject(of: NSString.self, forKey: "region") as String?,
		      let expiresAt = coder.decodeObject(of: NSDate.self, forKey: "expiresAt") as Date?
		else {
			return nil
		}

		self.accessToken = accessToken
		self.refreshToken = refreshToken
		self.expiresAt = expiresAt
		self.region = region
		self.startURL = startURL
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.accessToken, forKey: "accessToken")
		coder.encode(self.refreshToken, forKey: "refreshToken")
		coder.encode(self.expiresAt, forKey: "expiresAt")
		coder.encode(self.region, forKey: "region")
		coder.encode(self.startURL, forKey: "startURL")
	}

	static func fromAWS(input: AWSSSOOIDC.StartDeviceAuthorizationInput, output: AWSSSOOIDC.CreateTokenOutput,
	                    region: String) -> Result<SecureAWSSSOAccessToken, Error>
	{
		if let accessToken = output.accessToken, let startURL = input.startUrl {
			return .success(SecureAWSSSOAccessToken(
				accessToken: accessToken,
				refreshToken: "nope",
				expiresAt: Date().addingTimeInterval(Double(output.expiresIn)),
				region: region,
				startURL: URL(string: startURL)!
			))
		}
		return .failure(x.error("missing values"))
	}
}

public func signin(storage: some XDK.StorageAPI) -> Result<SecureAWSSSOAccessToken?, Error> {
	var err: Error?

	guard let current = XDK.Read(using: storage, SecureAWSSSOAccessToken.self).to(&err) else {
		return .failure(x.error("error loading access token", root: err))
	}

	if let current {
		if current.expiresAt.timeIntervalSince(Date().addingTimeInterval(5.0 * 60 * -1)) > 0.0 {
			return .success(current)
		}
	}

	return .success(nil)
}

public func signin(
	client: AWSSSOSDKProtocolWrapped,
	storageAPI: some XDK.StorageAPI,
	ssoRegion: String,
	startURL: URL,
	callback: @escaping (_ url: UserSignInData) -> Void
) async -> Result<SecureAWSSSOAccessToken, Error> {
	var err: Error? = nil

	guard let token = signin(storage: storageAPI).to(&err) else {
		return .failure(x.error("error loading access token", root: err))
	}

	if let token {
		return .success(token)
	}

	guard let registration = await registerClientIfNeeded(awsssoAPI: client, storageAPI: storageAPI).to(&err) else {
		return .failure(x.error("error registering client", root: err))
	}

	let input = AWSSSOOIDC.StartDeviceAuthorizationInput(
		clientId: registration.clientID,
		clientSecret: registration.clientSecret,
		startUrl: startURL.absoluteString
	)

	guard let deviceAuth = await client.startDeviceAuthorization(input: input).to(&err) else {
		return .failure(x.error("error starting device auth", root: err))
	}

	let data = UserSignInData.fromAWS(deviceAuth)

	callback(data)

	guard let tok = await pollForToken(client, registration: registration, deviceAuth: data, pollInterval: 1.0, expirationTime: 60.0).to(&err)
	else {
		return .failure(x.error("error polling for token", root: err))
	}

	guard let work = SecureAWSSSOAccessToken.fromAWS(input: input, output: tok, region: ssoRegion).to(&err) else {
		return .failure(x.error("error creating secure access token", root: err))
	}

	guard let _ = XDK.Write(using: storageAPI, work).to(&err) else {
		return .failure(x.error("error writing secure access token", root: err))
	}

	return .success(work)
}

func pollForToken(
	_ client: AWSSSOSDKProtocolWrapped,
	registration: SecureAWSSSOClientRegistrationInfo,
	deviceAuth: UserSignInData,
	pollInterval: TimeInterval,
	expirationTime: TimeInterval
) async -> Result<AWSSSOOIDC.CreateTokenOutput, Error> {
	// Calculate the expiration time as a Date
	let expirationDate = Date().addingTimeInterval(expirationTime)

	while Date() < expirationDate {
		var err: Error? = nil
		guard let tokenOutput = await client.createToken(input: .init(
			clientId: registration.clientID,
			clientSecret: registration.clientSecret,
			deviceCode: deviceAuth.code,
			grantType: "urn:ietf:params:oauth:grant-type:device_code"
		)).to(&err) else {
			let errd = err as! XError
			if errd.root() is AWSSSOOIDC.AuthorizationPendingException {
				// If the error is "AuthorizationPending", wait for the pollInterval and then try again
				print("SSO login still pending, continuing polling")
				try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
				continue
			} else {
				// For any other error, return failure
				return .failure(x.error("SSO Login failed", root: err))
			}
		}

		return .success(tokenOutput)
	}

	// If the loop exits because the expiration time is reached, return a timeout error
	return .failure(NSError(domain: "SSOService", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSO login timed out"]))
}

func registerClientIfNeeded(awsssoAPI: AWSSSOSDKProtocolWrapped,
                            storageAPI: some XDK.StorageAPI) async -> Result<SecureAWSSSOClientRegistrationInfo, Error>
{
	// Check if client is already registered and saved in secure storage (Keychain)

	var err: Error? = nil

	guard let reg = XDK.Read(using: storageAPI, SecureAWSSSOClientRegistrationInfo.self).to(&err) else {
		return .failure(x.error("error loading client registration", root: err))
	}

	if let reg {
		return .success(reg)
	}

	let regClientInput = AWSSSOOIDC.RegisterClientInput(clientName: "spatial-aws-basic", clientType: "public", scopes: [])

	// No registration found, register a new client
	guard let regd = await awsssoAPI.registerClient(input: regClientInput).to(&err) else {
		return .failure(x.error("error registering client", root: err))
	}

	guard let work = SecureAWSSSOClientRegistrationInfo.fromAWS(regd).to(&err) else {
		return .failure(x.error("error creating secure client registration", root: err))
	}

	guard let _ = XDK.Write(using: storageAPI, work).to(&err) else {
		return .failure(x.error("error writing secure client registration", root: err))
	}

	return .success(work)
}
