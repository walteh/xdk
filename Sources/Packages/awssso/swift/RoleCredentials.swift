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
import Err

struct RoleCredentialsSignInToken: Codable, Sendable {
	public let token: String
	public let credentialID: String

	init(token: String, credentialID: String) {
		self.token = token
		self.credentialID = credentialID
	}
}

public struct RoleCredentials: Codable, Sendable {
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

	public init(_ aws: AWSSSO.SSOClientTypes.RoleCredentials, _ role: RoleInfo, stsRegion: String) {
		self.init(
			accessKeyID: aws.accessKeyId ?? "",
			expiresAt: Date(timeIntervalSince1970: Double(Double(aws.expiration) / 1000)),
			secretAccessKey: aws.secretAccessKey ?? "",
			sessionToken: aws.sessionToken ?? "",
			role: role,
			stsRegion: stsRegion
		)
	}

	func expiresIn() -> TimeInterval {
		self.expiresAt.timeIntervalSinceNow
	}

	func isExpired() -> Bool {
		self.expiresIn() < 0
	}
}

@err func invalidateRoleCredentials(_ storage: some StorageAPI, role: RoleInfo) -> Result<Bool, Error> {


	// let res = #autoreturn { return true }

	guard let _ = XDK.Delete(using: storage, RoleCredentials.self, differentiator: role.uniqueID + XDKAWSSSO_KEYCHAIN_VERSION).get() else {
		return .failure(x.error("error deleting role creds from keychain", root: err))
	}

	return .success(true)
}

@err func invalidateAndGetRoleCredentialsUsing(
	sso client: any AWSSSOSDKProtocolWrapped,
	storage: some StorageAPI,
	accessToken: SecureAWSSSOAccessToken,
	role: RoleInfo
) async -> Result<RoleCredentialsStatus, Error> {


	guard let _ = invalidateRoleCredentials(storage, role: role).get() else {
		return .failure(x.error("error deleting role creds from keychain", root: err))
	}

	return await getRoleCredentialsUsing(sso: client, storage: storage, accessToken: accessToken, role: role)
}

public struct RoleCredentialsStatus: Sendable {
	public let data: RoleCredentials
	let pulledFromCache: Bool
}

@err public func getRoleCredentialsUsing(
	sso client: any AWSSSOSDKProtocolWrapped,
	storage: some StorageAPI,
	accessToken: AccessToken,
	role: RoleInfo
) async -> Result<RoleCredentialsStatus, Error> {


	let myid = role.uniqueID + XDKAWSSSO_KEYCHAIN_VERSION

	guard let curr = XDK.Read(using: storage, RoleCredentials.self, differentiator: myid).get() else {
		return .failure(x.error("error reading role creds from keychain", root: err))
	}

	// dereference err1

	if let curr {
		if curr.expiresIn() > 60 * 5, curr.expiresIn() < 60 * 60 * 24 * 7 {
			XDK.Log(.debug).info("creds", curr.accessKeyID).info("account", role.accountID).info("role", role.roleName)
				.info("expiresIn", curr.expiresIn()).send("using cached creds")
			return .success(RoleCredentialsStatus(data: curr, pulledFromCache: true))
		} else {
			XDK.Log(.debug).add("expires_in", any: curr.expiresIn().seconds()).add("expires_at", curr.expiresAt)
				.send("creds are expired, creating new ones")
		}
	}

	// into this at compile time
	guard let creds = await client.getRoleCredentials(input: .init(
		accessToken: accessToken.token(),
		accountId: role.accountID,
		roleName: role.roleName
	)).get() else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	guard let rolecreds = creds.roleCredentials else {
		return .failure(x.error("roleCredentials does not exist"))
	}

	let rcreds = RoleCredentials(rolecreds, role, stsRegion: accessToken.stsRegion())

	guard let _ = XDK.Write(using: storage, rcreds, overwrite: true, differentiator: myid).get() else {
		return .failure(x.error("error writing role creds to keychain", root: err))
	}

	XDK.Log(.debug).info("creds", rcreds.accessKeyID).info("account", role.accountID).info("uniqueID", role.uniqueID).info("role", role.roleName).info("expiresAt", rcreds.expiresAt).send("writing creds to cache")

	return .success(RoleCredentialsStatus(data: rcreds, pulledFromCache: false))
}

@err func fetchCachedSignInToken(
	storage: some StorageAPI,
	credentials: RoleCredentials
) async -> Result<RoleCredentialsSignInToken, Error> {


	let myid = credentials.role.uniqueID + XDKAWSSSO_KEYCHAIN_VERSION

	guard let curr = XDK.Read(using: storage, RoleCredentialsSignInToken.self, differentiator: myid).get() else {
		return .failure(x.error("error reading signin token from keychain", root: err))
	}

	if let curr {
		if curr.credentialID == credentials.uniqueID, curr.token.count > 0 {
			return .success(curr)
		}
	}

	guard let signInToken = await fetchSignInToken(with: credentials).get() else {
		return .failure(x.error("error fetching signin token", root: err))
	}

	let tok = RoleCredentialsSignInToken(token: signInToken, credentialID: credentials.uniqueID)

	guard let _ = XDK.Write(using: storage, tok, overwrite: true, differentiator: myid).get() else {
		return .failure(x.error("error writing signin token to keychain", root: err))
	}

	return .success(tok)
}

@err func fetchSignInToken(with credentials: RoleCredentials, retryNumber: Int = 0) async -> Result<String, Error> {


	guard let request = constructFederationURLRequest(with: credentials).get() else {
		return .failure(x.error("error constructing federation url", root: err))
	}

	guard let (data, response) = await Result({ try await URLSession.shared.data(for: request) }).get() else {
		return .failure(x.error("error fetching sign in token", root: err))
	}

	guard let httpResponse = response as? HTTPURLResponse else {
		return .failure(x.error("unexpected response type: \(response)"))
	}

	if httpResponse.statusCode == 400 {
		if retryNumber < 5, retryNumber >= 0 {
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

	guard let jsonResultz = try JSONSerialization.jsonObject(with: data) else {
		return .failure(x.error("error parsing json", root: err))
	}

	guard let jsonResult = jsonResultz as? [String: Any] else {
		return .failure(x.error("no json data returned"))
	}



	XDK.Log(.debug).info("jsonResult", jsonResult).send("fetchSignInToken")

	if let signInToken = jsonResult["SigninToken"] as? String {
		return .success(signInToken)
	} else {
		return .failure(x.error("error parsing json"))
	}
}
