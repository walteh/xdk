//
//  AccountRole.swift
//
//  Created by walter on 1/29/24.
//

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK

public struct AccountRole: Hashable, Equatable {
	public let accountID: String
	public let role: String
	public let accountName: String
	public let accountEmail: String

	var uniqueId: String {
		return "\(self.accountID) - \(self.role)"
	}

	init(accountID: String, accountName: String, role: String, accountEmail: String) {
		self.accountID = accountID
		self.role = role
		self.accountName = accountName
		self.accountEmail = accountEmail
	}

	init(role: AWSSSO.SSOClientTypes.RoleInfo, account: AWSSSO.SSOClientTypes.AccountInfo) {
		self.accountID = account.accountId ?? ""
		self.role = role.roleName ?? ""
		self.accountName = account.accountName ?? ""
		self.accountEmail = account.emailAddress ?? ""
	}
}

func listAccounts(_ client: AWSSSO.SSOClient, accessToken: SecureAWSSSOAccessToken) async -> Result<[AccountRole], Error> {
	var err: Error? = nil

	guard let response = await Result.X({ try await client.listAccounts(input: .init(accessToken: accessToken.accessToken)) }).to(&err) else {
		return .failure(x.error("error fetching accounts", root: err))
	}

	var accounts = [AccountRole]()
	guard let accountList = response.accountList else {
		return .failure(x.error("response.accountList does not exist"))
	}
	// Iterate over accounts and fetch roles for each
	for account in accountList {
		// sleep for 1 second to avoid throttling
		sleep(1)
		guard let roles = await listRolesForAccount(client, accessToken: accessToken, account: account).to(&err) else {
			return .failure(x.error("error fetching roles for account", root: err).info("accountID", account.accountId!).info("accountName", account.accountName!))
		}
		for role in roles {
			accounts.append(role)
		}
	}

	return .success(accounts)
}

func listRolesForAccount(_ client: AWSSSO.SSOClient, accessToken: SecureAWSSSOAccessToken, account: AWSSSO.SSOClientTypes.AccountInfo) async -> Result<[AccountRole], Error> {
	// List roles for the given account
	let _rolesResponse = await Result.X {
		try await client.listAccountRoles(input: .init(accessToken: accessToken.accessToken, accountId: account.accountId!))
	}
	guard let rolesResponse = _rolesResponse.value else { return .failure(_rolesResponse.error!) }

	var roles = [AccountRole]()
	if let roleList = rolesResponse.roleList {
		for role in roleList {
			roles.append(AccountRole(role: role, account: account))
		}
	} else {
		return .failure(x.error("No roles found for account").info("accountID", account.accountId).info("accountName", account.accountName))
	}

	return .success(roles)
}
