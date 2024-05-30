//
//  RoleCredentials.swift
//
//  Created by walter on 1/19/24.
//

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK

class RoleCredentialsSignInToken: NSObject, NSSecureCoding {
	public let token: String
	public let credentialID: String

	init(token: String, credentialID: String) {
		self.token = token
		self.credentialID = credentialID
	}

	// MARK: NSSecureCoding

	public static

	var supportsSecureCoding: Bool { true }

	public required init?(coder: NSCoder) {
		self.token = coder.decodeObject(of: NSString.self, forKey: "token") as String? ?? ""
		self.credentialID = coder.decodeObject(of: NSString.self, forKey: "credentialID") as String? ?? ""
	}

	func encode(with coder: NSCoder) {
		coder.encode(self.token as NSString, forKey: "token")
		coder.encode(self.credentialID as NSString, forKey: "credentialID")
	}
}

class RoleCredentials: NSObject, NSSecureCoding {
	public let accessKeyID: Swift.String
	public let expiresAt: Date
	public let secretAccessKey: Swift.String
	public let sessionToken: Swift.String
	public let role: RoleInfo
	public let stsRegion: Swift.String
	public let uniqueID: String

	public init(
		accessKeyID: Swift.String,
		expiresAt: Date,
		secretAccessKey: Swift.String,
		sessionToken: Swift.String,
		role: RoleInfo,
		stsRegion: Swift.String
	) {
		self.uniqueID = XDK.XID.build().string()
		self.accessKeyID = accessKeyID
		self.expiresAt = expiresAt
		self.secretAccessKey = secretAccessKey
		self.sessionToken = sessionToken
		self.role = role
		self.stsRegion = stsRegion
	}

	public convenience init(_ aws: AWSSSO.SSOClientTypes.RoleCredentials, _ role: RoleInfo, stsRegion: String) {
		self.init(
			accessKeyID: aws.accessKeyId ?? "",
			expiresAt: Date(timeIntervalSince1970: Double(Double(aws.expiration) / 1000)),
			secretAccessKey: aws.secretAccessKey ?? "",
			sessionToken: aws.sessionToken ?? "",
			role: role,
			stsRegion: stsRegion
		)
	}

	// MARK: NSSecureCoding

	public static var supportsSecureCoding: Bool { true }

	public required init?(coder: NSCoder) {
		self.uniqueID = coder.decodeObject(of: NSString.self, forKey: "uniqueID") as String? ?? ""
		self.accessKeyID = coder.decodeObject(of: NSString.self, forKey: "accessKeyID") as String? ?? ""
		self.role = coder.decodeObject(of: [RoleInfo.self], forKey: "role") as? RoleInfo ?? RoleInfo(roleName: "", accountID: "")
		self.expiresAt = coder.decodeObject(of: NSDate.self, forKey: "expiresAt") as? Date ?? Date()
		self.secretAccessKey = coder.decodeObject(of: NSString.self, forKey: "secretAccessKey") as? String ?? ""
		self.sessionToken = coder.decodeObject(of: NSString.self, forKey: "sessionToken") as? String ?? ""
		self.stsRegion = coder.decodeObject(of: NSString.self, forKey: "stsRegion") as? String ?? ""
	}

	func encode(with coder: NSCoder) {
		coder.encode(self.uniqueID, forKey: "uniqueID")
		coder.encode(self.accessKeyID, forKey: "accessKeyID")
		coder.encode(self.secretAccessKey, forKey: "secretAccessKey")
		coder.encode(self.expiresAt, forKey: "expiresAt")
		coder.encode(self.sessionToken, forKey: "sessionToken")
		coder.encode(self.role, forKey: "role")
		coder.encode(self.stsRegion, forKey: "stsRegion")
	}

	func expiresIn() -> TimeInterval {
		return self.expiresAt.timeIntervalSinceNow
	}

	func isExpired() -> Bool {
		return self.expiresIn() < 0
	}
}

func invalidateRoleCredentials(_ storage: some StorageAPI, account: RoleInfo) -> Result<Bool, Error> {
	var err: Error? = nil

	guard let _ = XDK.Delete(using: storage, RoleCredentials.self, differentiator: account.uniqueID).to(&err) else {
		return .failure(x.error("error deleting role creds from keychain", root: err))
	}

	return .success(true)
}

func invalidateAndGetRoleCredentials(
	_ client: any AWSSSOSDKProtocolWrapped,
	storage: some StorageAPI,
	accessToken: SecureAWSSSOAccessToken,
	account: RoleInfo
) async -> Result<RoleCredentialsStatus, Error> {
	var err: Error? = nil

	guard let _ = invalidateRoleCredentials(storage, account: account).to(&err) else {
		return .failure(x.error("error deleting role creds from keychain", root: err))
	}

	return await getRoleCredentials(client, storage: storage, accessToken: accessToken, account: account)
}

struct RoleCredentialsStatus {
	let data: RoleCredentials
	let pulledFromCache: Bool
}

func getRoleCredentials(
	_ client: any AWSSSOSDKProtocolWrapped,
	storage: some StorageAPI,
	accessToken: SecureAWSSSOAccessToken,
	account: RoleInfo
) async -> Result<RoleCredentialsStatus, Error> {
	var err: Error? = nil

	guard let curr = XDK.Read(using: storage, RoleCredentials.self, differentiator: account.uniqueID).to(&err) else {
		return .failure(x.error("error reading role creds from keychain", root: err))
	}

	// dereference err1

	if let curr {
		if curr.expiresIn() > 60 * 5, curr.expiresIn() < 60 * 60 * 24 * 7 {
			XDK.Log(.debug).info("creds", curr.accessKeyID).info("account", account.accountID).info("role", account.roleName)
				.info("expiresIn", curr.expiresIn()).send("using cached creds")
			return .success(RoleCredentialsStatus(data: curr, pulledFromCache: true))
		} else {
			XDK.Log(.debug).add("expires_in", any: curr.expiresIn().seconds()).add("expires_at", curr.expiresAt)
				.send("creds are expired, creating new ones")
		}
	}

	// into this at compile time
	guard let creds = await client.getRoleCredentials(input: .init(
		accessToken: accessToken.accessToken,
		accountId: account.accountID,
		roleName: account.roleName
	)).to(&err) else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	guard let rolecreds = creds.roleCredentials else {
		return .failure(x.error("roleCredentials does not exist"))
	}

	// XDK.Log(.info).info("sessioTokenFromAWS", rolecreds.sessionToken).info("account", account.accountID).info("role",
	// account.role).send("fetched role creds")

	let rcreds = RoleCredentials(rolecreds, account, stsRegion: accessToken.region)

	// XDK.Log(.debug).info("savedSessionToken", rcreds.sessionToken).info("account", account.accountID).info("role",
	// account.role).send("saving role creds")

	guard let _ = XDK.Write(using: storage, rcreds, overwrite: true, differentiator: account.uniqueID).to(&err) else {
		return .failure(x.error("error writing role creds to keychain", root: err))
	}

	XDK.Log(.debug).info("creds", rcreds.accessKeyID).info("account", account.accountID).info("uniqueID", account.uniqueID)
		.info("role", account.roleName).info("expiresAt", rcreds.expiresAt).send("writing creds to cache")

	return .success(RoleCredentialsStatus(data: rcreds, pulledFromCache: false))
}

func fetchCachedSignInToken(
	storage: some StorageAPI,
	credentials: RoleCredentials
) async -> Result<RoleCredentialsSignInToken, Error> {
	var err: Error? = nil

	guard let curr = XDK.Read(using: storage, RoleCredentialsSignInToken.self, differentiator: credentials.role.uniqueID).to(&err) else {
		return .failure(x.error("error reading signin token from keychain", root: err))
	}

	if let curr {
		if curr.credentialID == credentials.uniqueID, curr.token.count > 0 {
			return .success(curr)
		}
	}

	guard let signInToken = await fetchSignInToken(with: credentials).to(&err) else {
		return .failure(x.error("error fetching signin token", root: err))
	}

	let tok = RoleCredentialsSignInToken(token: signInToken, credentialID: credentials.uniqueID)

	guard let _ = XDK.Write(using: storage, tok, overwrite: true, differentiator: credentials.role.uniqueID).to(&err) else {
		return .failure(x.error("error writing signin token to keychain", root: err))
	}

	return .success(tok)
}

func fetchSignInToken(with credentials: RoleCredentials, retryNumber: Int = 0) async -> Result<String, Error> {
	var err: Error? = nil

	guard let request = constructFederationURLRequest(with: credentials).to(&err) else {
		return .failure(x.error("error constructing federation url", root: err))
	}

	guard let (data, response) = await Result.X({ try await URLSession.shared.data(for: request) }).to(&err) else {
		return .failure(x.error("error fetching sign in token", root: err))
	}

	guard let httpResponse = response as? HTTPURLResponse else {
		return .failure(x.error("unexpected response type: \(response)"))
	}

	if httpResponse.statusCode == 400 {
		if retryNumber < 5 && retryNumber >= 0 {
			XDK.Log(.debug).add("account", credentials.role.accountID).add("count", any: retryNumber).send("retrying fetchSignInToken")
			return await fetchSignInToken(with: credentials, retryNumber: retryNumber + 1)
		}
	}

	if httpResponse.statusCode != 200 {
		// add info but only the first 10 and last 10 chars
		let lastfirst = String(data: data, encoding: .utf8)!.prefix(10) + "..." + String(data: data, encoding: .utf8)!.suffix(10).replacingOccurrences(of: "\n", with: "")

		return .failure(x.error("unexpected error code: \(httpResponse.statusCode)").info("body", lastfirst).info("url", request.url?.absoluteString ?? "none"))
	} else {
		XDK.Log(.debug).add("request_url", request.url?.absoluteString ?? "none").send("success on fetchSignInToken")
	}

	guard let jsonResult = Result.X({ try JSONSerialization.jsonObject(with: data) as? [String: Any] }).to(&err) else {
		return .failure(x.error("error parsing json", root: err))
	}

	if jsonResult == nil {
		return .failure(x.error("no json data returned"))
	}

	XDK.Log(.debug).info("jsonResult", jsonResult!).send("fetchSignInToken")

	if let signInToken = jsonResult!["SigninToken"] as? String {
		return .success(signInToken)
	} else {
		return .failure(x.error("error parsing json"))
	}
}
