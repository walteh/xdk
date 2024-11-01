//
//  AccountRole.swift
//
//  Created by walter on 1/29/24.
//

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import WebKit
import XDK
import Err

public protocol ManagedRegionService: Sendable {
	var region: String? { get set }
	var service: String? { get set }
}

public struct SimpleManagedRegionService: ManagedRegionService {
	public var region: String?
	public var service: String?

	public init(region: String?, service: String?) {
		self.region = region
		self.service = service
	}
}

public struct RoleInfo: Codable, Sendable, Hashable {
	public let roleName: String
	public let accountID: String

	init(_ aws: AWSSSO.SSOClientTypes.RoleInfo) {
		self.roleName = aws.roleName ?? ""
		self.accountID = aws.accountId ?? ""
	}

	public init(roleName: String, accountID: String) {
		self.roleName = roleName
		self.accountID = accountID
	}

	public var uniqueID: String {
		"\(self.accountID)_\(self.roleName)"
	}
}

public struct AccountInfo: Codable, Sendable, Hashable {
	public static func == (lhs: AccountInfo, rhs: AccountInfo) -> Bool {
		return lhs.accountID == rhs.accountID
	}

	public let accountID: String
	public let roles: [RoleInfo]
	public let accountName: String
	public let accountEmail: String

	public init(accountID: String, accountName: String, roles: [RoleInfo], accountEmail: String) {
		self.accountID = accountID
		self.accountName = accountName
		self.accountEmail = accountEmail
		self.roles = roles
	}

	init(role: [AWSSSO.SSOClientTypes.RoleInfo], account: AWSSSO.SSOClientTypes.AccountInfo) {
		self.accountID = account.accountId ?? ""
		self.roles = role.map { RoleInfo($0) }
		self.accountName = account.accountName ?? ""
		self.accountEmail = account.emailAddress ?? ""
	}
}

public struct RoleInfoList: Codable, Sequence, Sendable {
	public var roles: [RoleInfo]

	public init(roles: [RoleInfo]) {
		self.roles = roles
	}

	public func makeIterator() -> IndexingIterator<[RoleInfo]> {
		self.roles.makeIterator()
	}
}

public struct AccountInfoList: Codable, Sequence, Sendable {
	public var accounts: [AccountInfo]

	public init(accounts: [AccountInfo]) {
		self.accounts = accounts
	}

	public func makeIterator() -> IndexingIterator<[AccountInfo]> {
		self.accounts.makeIterator()
	}
}

func invalidateAccountsRoleList(storage: XDK.StorageAPI) -> Result<Void, Error> {
	XDK.Delete(using: storage, AccountInfoList.self)
}

@err public func getAccountsRoleList(
	client: AWSSSOSDKProtocolWrapped,
	storage: XDK.StorageAPI,
	accessToken: AccessToken
) async -> Result<AccountInfoList, Error> {

	let myid = accessToken.source() + XDKAWSSSO_KEYCHAIN_VERSION

	// check storage
	guard let cached = XDK.Read(using: storage, AccountInfoList.self, differentiator: myid).get() else {
		return .failure(x.error("error loading accounts from storage", root: err))
	}

	if let cached {
		return .success(cached)
	}

	guard let response = await client.listAccounts(input: .init(accessToken: accessToken.token())).get() else {
		return .failure(x.error("error fetching accounts", root: err))
	}

	guard let accountList = response.accountList else {
		return .failure(x.error("response.accountList does not exist"))
	}

	var list = AccountInfoList(accounts: [])

	// Iterate over accounts and fetch roles for each
	for account in accountList {
		guard let roles = try await listRolesForAccount(client: client, accessToken: accessToken, account: account).get() else {
			return .failure(x.error("error fetching roles for account", root: err).info("accountID", account.accountId!)
				.info("accountName", account.accountName!))
		}
		for role in roles {
			list.accounts.append(role)
		}
	}

	// save to storage
	guard let _ = XDK.Write(using: storage, list, differentiator: myid).get() else {
		return .failure(x.error("error saving accounts to storage", root: err))
	}

	return .success(list)
}

@err func listRolesForAccount(
	client: AWSSSOSDKProtocolWrapped,
	accessToken: AccessToken,
	account: AWSSSO.SSOClientTypes.AccountInfo
) async -> Result<[AccountInfo], Error> {
	guard let rolesResponse = await client.listAccountRoles(input: .init(accessToken: accessToken.token(), accountId: account.accountId!)).get()	else {
		return .failure(x.error("error fetching roles for account", root: err).info("accountID", account.accountId!)
			.info("accountName", account.accountName!))
	}

	var list = [AccountInfo]()
	if let roleList = rolesResponse.roleList {
		list.append(AccountInfo(role: roleList, account: account))
	} else {
		return .failure(x.error("No roles found for account").info("accountID", account.accountId ?? "nil")
			.info("accountName", account.accountName ?? "nil"))
	}

	return .success(list)
}
