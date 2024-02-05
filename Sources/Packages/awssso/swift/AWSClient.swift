

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK

public protocol AWSClient {
	var ssoRegion: String { get }
	// var sso: AWSSSO.SSOClientProtocol { get }
	// var ssoOIDC: AWSSSOOIDC.SSOOIDCClientProtocol { get }

	func getRoleCredentials(input: AWSSSO.GetRoleCredentialsInput) async -> Result<AWSSSO.GetRoleCredentialsOutput, Error>
	func startDeviceAuthorization(input: AWSSSOOIDC.StartDeviceAuthorizationInput) async -> Result<AWSSSOOIDC.StartDeviceAuthorizationOutput, Error>
	func listAccounts(input: AWSSSO.ListAccountsInput) async -> Result<AWSSSO.ListAccountsOutput, Error>
	func listAccountRoles(input: AWSSSO.ListAccountRolesInput) async -> Result<AWSSSO.ListAccountRolesOutput, Error>
}

class AWSSSOClientImpl: AWSClient {
	let ssoRegion: String
	let sso: AWSSSO.SSOClientProtocol
	let ssoOIDC: AWSSSOOIDC.SSOOIDCClientProtocol

	init(ssoRegion: String) throws {
		self.ssoRegion = ssoRegion
		self.sso = try AWSSSO.SSOClient(region: self.ssoRegion)
		self.ssoOIDC = try AWSSSOOIDC.SSOOIDCClient(region: self.ssoRegion)
	}

	func getRoleCredentials(input: AWSSSO.GetRoleCredentialsInput) async -> Result<AWSSSO.GetRoleCredentialsOutput, Error> {
		return await Result.X { try await self.sso.getRoleCredentials(input: input) }
	}

	func startDeviceAuthorization(input: AWSSSOOIDC.StartDeviceAuthorizationInput) async -> Result<AWSSSOOIDC.StartDeviceAuthorizationOutput, Error> {
		return await Result.X { try await self.ssoOIDC.startDeviceAuthorization(input: input) }
	}

	func listAccounts(input: AWSSSO.ListAccountsInput) async -> Result<AWSSSO.ListAccountsOutput, Error> {
		return await Result.X { try await self.sso.listAccounts(input: input) }
	}

	func listAccountRoles(input: AWSSSO.ListAccountRolesInput) async -> Result<AWSSSO.ListAccountRolesOutput, Error> {
		return await Result.X { try await self.sso.listAccountRoles(input: input) }
	}
}

public class SecureAWSSSOClientRegistrationInfo: NSObject, NSSecureCoding {
	public static var supportsSecureCoding: Bool = true

	let clientID: String
	let clientSecret: String

	init(clientID: String, clientSecret: String) {
		self.clientID = clientID
		self.clientSecret = clientSecret
	}

	// MARK: - NSSecureCoding

	public required init?(coder: NSCoder) {
		self.clientID = coder.decodeObject(forKey: "clientId") as? String ?? ""
		self.clientSecret = coder.decodeObject(forKey: "clientSecret") as? String ?? ""
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.clientID, forKey: "clientId")
		coder.encode(self.clientSecret, forKey: "clientSecret")
	}

	static func fromAWS(_ input: AWSSSOOIDC.RegisterClientOutput) -> Result<SecureAWSSSOClientRegistrationInfo, Error> {
		if let clientID = input.clientId, let clientSecret = input.clientSecret {
			return .success(SecureAWSSSOClientRegistrationInfo(clientID: clientID, clientSecret: clientSecret))
		}
		return .failure(x.error("missing values"))
	}
}
