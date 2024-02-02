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

public class RoleInfo: NSObject, NSSecureCoding {
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

	var uniqueID: String {
		return "\(self.accountID)_\(self.roleName)"
	}

	// MARK: - NSSecureCoding

	public static var supportsSecureCoding: Bool = true

	public required init?(coder: NSCoder) {
		self.roleName = coder.decodeObject(of: NSString.self, forKey: "roleName") as String? ?? ""
		self.accountID = coder.decodeObject(of: NSString.self, forKey: "accountID") as String? ?? ""
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.roleName, forKey: "roleName")
		coder.encode(self.accountID, forKey: "accountID")
	}
}

public class AccountInfo: NSObject, NSSecureCoding, ObservableObject {
	public let accountID: String
	public let roles: [RoleInfo]
	@Published public var role: RoleInfo?
	public let accountName: String
	public let accountEmail: String

	// this doesn't need to be here, but we can use it centralize the region
	// @Published public var region: String?

	var currentRoleUniqueId: String {
		return "\(self.accountID)_\(self.role?.roleName ?? "none")"
	}

	public init(accountID: String, accountName: String, roles: [RoleInfo], accountEmail: String) {
		self.accountID = accountID
		self.accountName = accountName
		self.accountEmail = accountEmail
		self.roles = roles
		self.role = roles.first
	}

	init(role: [AWSSSO.SSOClientTypes.RoleInfo], account: AWSSSO.SSOClientTypes.AccountInfo) {
		self.accountID = account.accountId ?? ""
		self.roles = role.map { RoleInfo($0) }
		self.role = self.roles.first ?? nil
		self.accountName = account.accountName ?? ""
		self.accountEmail = account.emailAddress ?? ""
	}

	// MARK: - NSSecureCoding

	// implement the NSSecureCoding protocol
	public static var supportsSecureCoding: Bool = true

	public required init?(coder: NSCoder) {
		self.accountID = coder.decodeObject(of: NSString.self, forKey: "accountID") as String? ?? ""
		self.role = coder.decodeObject(of: [RoleInfo.self], forKey: "role") as? RoleInfo ?? nil
		self.roles = coder.decodeObject(of: [NSArray.self, RoleInfo.self], forKey: "roles") as? [RoleInfo] ?? []
		self.accountName = coder.decodeObject(of: NSString.self, forKey: "accountName") as? String ?? ""
		self.accountEmail = coder.decodeObject(of: NSString.self, forKey: "accountEmail") as? String ?? ""
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.accountID, forKey: "accountID")
		coder.encode(self.role, forKey: "role")
		coder.encode(self.roles as NSArray, forKey: "roles")
		coder.encode(self.accountName, forKey: "accountName")
		coder.encode(self.accountEmail, forKey: "accountEmail")
	}
}

public class RoleInfoList: NSObject, Sequence, NSSecureCoding {
	public var roles: [RoleInfo]

	public init(roles: [RoleInfo]) {
		self.roles = roles
	}

	public func makeIterator() -> IndexingIterator<[RoleInfo]> {
		return self.roles.makeIterator()
	}

	// MARK: - NSSecureCoding

	public static var supportsSecureCoding = true

	public required init?(coder: NSCoder) {
		guard let decodedArray = coder.decodeObject(of: [NSArray.self, RoleInfo.self], forKey: "roles") as? [RoleInfo] else {
			return nil
		}
		self.roles = decodedArray
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.roles as NSArray, forKey: "roles")
	}
}

public class AccountInfoList: NSObject, Sequence, NSSecureCoding {
	public var accounts: [AccountInfo]

	public init(accounts: [AccountInfo]) {
		self.accounts = accounts
	}

	public func makeIterator() -> IndexingIterator<[AccountInfo]> {
		return self.accounts.makeIterator()
	}

	// MARK: - NSSecureCoding

	public static var supportsSecureCoding = true

	public required init?(coder: NSCoder) {
		guard let decodedArray = coder.decodeObject(of: [NSArray.self, AccountInfo.self], forKey: "accounts") as? [AccountInfo] else {
			return nil
		}
		self.accounts = decodedArray
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.accounts as NSArray, forKey: "accounts")
	}
}

func createWebView() -> WKWebView {
	let webViewConfig = WKWebViewConfiguration()
	webViewConfig.websiteDataStore = WKWebsiteDataStore.nonPersistent()
	let webView = WKWebView(frame: .zero, configuration: webViewConfig)
	return webView
}

func invalidateAccountsRoleList(storage: XDK.StorageAPI) -> Result<Void, Error> {
	return XDK.Delete(using: storage, AccountInfoList.self)
}

func getAccountsRoleList(storage: XDK.StorageAPI, _ client: AWSSSO.SSOClient, accessToken: SecureAWSSSOAccessToken) async -> Result<AccountInfoList, Error> {
	var err: Error? = nil

	// check storage
	guard let cached = XDK.Read(using: storage, AccountInfoList.self).to(&err) else {
		return .failure(x.error("error loading accounts from storage", root: err))
	}

	if let cached {
		return .success(cached)
	}

	guard let response = await Result.X({ try await client.listAccounts(input: .init(accessToken: accessToken.accessToken)) }).to(&err) else {
		return .failure(x.error("error fetching accounts", root: err))
	}

	guard let accountList = response.accountList else {
		return .failure(x.error("response.accountList does not exist"))
	}

	let list = AccountInfoList(accounts: [])

	// Iterate over accounts and fetch roles for each
	for account in accountList {
		guard let roles = await listRolesForAccount(client, accessToken: accessToken, account: account).to(&err) else {
			return .failure(x.error("error fetching roles for account", root: err).info("accountID", account.accountId!).info("accountName", account.accountName!))
		}
		for role in roles {
			list.accounts.append(role)
		}
	}

	// save to storage
	guard let _ = XDK.Write(using: storage, list).to(&err) else {
		return .failure(x.error("error saving accounts to storage", root: err))
	}

	return .success(list)
}

func listRolesForAccount(_ client: AWSSSO.SSOClient, accessToken: SecureAWSSSOAccessToken, account: AWSSSO.SSOClientTypes.AccountInfo) async -> Result<[AccountInfo], Error> {
	// List roles for the given account
	let _rolesResponse = await Result.X {
		try await client.listAccountRoles(input: .init(accessToken: accessToken.accessToken, accountId: account.accountId!))
	}
	guard let rolesResponse = _rolesResponse.value else { return .failure(_rolesResponse.error!) }

	var list = [AccountInfo]()
	if let roleList = rolesResponse.roleList {
		list.append(AccountInfo(role: roleList, account: account))
	} else {
		return .failure(x.error("No roles found for account").info("accountID", account.accountId ?? "nil").info("accountName", account.accountName ?? "nil"))
	}

	return .success(list)
}
