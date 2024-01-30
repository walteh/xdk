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

class RoleCredentials: NSObject, NSSecureCoding {
	public let accessKeyID: Swift.String
	public let expiresAt: Date
	public let secretAccessKey: Swift.String
	public let sessionToken: Swift.String

	public init(
		accessKeyID: Swift.String,
		expiresAt: Date,
		secretAccessKey: Swift.String,
		sessionToken: Swift.String
	) {
		self.accessKeyID = accessKeyID
		self.expiresAt = expiresAt
		self.secretAccessKey = secretAccessKey
		self.sessionToken = sessionToken
	}

	public convenience init(_ aws: AWSSSO.SSOClientTypes.RoleCredentials) {
		self.init(
			accessKeyID: aws.accessKeyId ?? "",
			expiresAt: Date(timeIntervalSince1970: Double(aws.expiration / 1000)),
			secretAccessKey: aws.secretAccessKey ?? "",
			sessionToken: aws.sessionToken ?? ""
		)
	}

	// MARK: NSSecureCoding

	public static var supportsSecureCoding: Bool { true }

	public required init?(coder: NSCoder) {
		guard let accessKeyID = coder.decodeObject(of: NSString.self, forKey: "accessKeyID") as String?,
		      let secretAccessKey = coder.decodeObject(of: NSString.self, forKey: "secretAccessKey") as String?,
		      let sessionToken = coder.decodeObject(of: NSString.self, forKey: "sessionToken") as String?,
		      let expiresAt = coder.decodeObject(of: NSDate.self, forKey: "expiresAt") as Date?
		else {
			return nil
		}

		self.accessKeyID = accessKeyID
		self.secretAccessKey = secretAccessKey
		self.sessionToken = sessionToken
		self.expiresAt = expiresAt
	}

	func encode(with coder: NSCoder) {
		coder.encode(self.accessKeyID, forKey: "accessKeyID")
		coder.encode(self.secretAccessKey, forKey: "secretAccessKey")
		coder.encode(self.expiresAt, forKey: "expiresAt")
		coder.encode(self.sessionToken, forKey: "sessionToken")
	}

	func expiresIn() -> TimeInterval {
		return self.expiresAt.timeIntervalSince(Date())
	}

	func isExpired() -> Bool {
		return self.expiresIn() < 0
	}
}

func invalidateRoleCredentials(_ storageAPI: some StorageAPI, account: AccountRole) -> Result<Bool, Error> {
	var err: Error? = nil

	guard let _ = XDK.Delete(using: storageAPI, RoleCredentials.self, differentiator: account.uniqueId).to(&err) else {
		return .failure(x.error("error deleting role creds from keychain", root: err))
	}

	return .success(true)
}

func invalidateAndGetRoleCredentials(_ client: AWSSSO.SSOClient, storageAPI: some StorageAPI, accessToken: SecureAWSSSOAccessToken, account: AccountRole) async -> Result<RoleCredentials, Error> {
	var err: Error? = nil

	guard let _ = invalidateRoleCredentials(storageAPI, account: account).to(&err) else {
		return .failure(x.error("error deleting role creds from keychain", root: err))
	}

	return await getRoleCredentials(client, storageAPI: storageAPI, accessToken: accessToken, account: account)
}

func getRoleCredentials(_ client: AWSSSO.SSOClient, storageAPI: some StorageAPI, accessToken: SecureAWSSSOAccessToken, account: AccountRole) async -> Result<RoleCredentials, Error> {
	var err: Error? = nil

	guard let curr = XDK.Read(using: storageAPI, RoleCredentials.self, differentiator: account.uniqueId).to(&err) else {
		return .failure(x.error("error reading role creds from keychain", root: err))
	}

	// dereference err1

	if let curr {
		if curr.expiresIn() > 60 * 5, curr.expiresIn() < 60 * 60 * 24 * 7 {
			XDK.Log(.debug).info("creds", curr.accessKeyID).info("account", account.accountID).info("role", account.role).info("expiresIn", curr.expiresIn()).send("using cached creds")
			return .success(curr)
		}
	}

	// into this at compile time
	guard let creds = await Result.X({ try await client.getRoleCredentials(input: .init(accessToken: accessToken.accessToken, accountId: account.accountID, roleName: account.role)) }).to(&err) else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	guard let rolecreds = creds.roleCredentials else {
		return .failure(x.error("roleCredentials does not exist"))
	}

	// XDK.Log(.info).info("sessioTokenFromAWS", rolecreds.sessionToken).info("account", account.accountID).info("role", account.role).send("fetched role creds")

	let rcreds = RoleCredentials(rolecreds)

	// XDK.Log(.debug).info("savedSessionToken", rcreds.sessionToken).info("account", account.accountID).info("role", account.role).send("saving role creds")

	guard let _ = XDK.Write(using: storageAPI, rcreds, overwrite: true, differentiator: account.uniqueId).to(&err) else {
		return .failure(x.error("error writing role creds to keychain", root: err))
	}

	XDK.Log(.debug).info("creds", rcreds.accessKeyID).info("account", account.accountID).info("uniqueId", account.uniqueId).info("role", account.role).info("expiresAt", rcreds.expiresAt).send("writing creds to cache")

	return .success(rcreds)
}
