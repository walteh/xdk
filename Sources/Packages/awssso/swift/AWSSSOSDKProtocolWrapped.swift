

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK

public protocol AWSSSOSDKProtocolWrapped {
	var ssoRegion: String { get }
	var sso: AWSSSO.SSOClient { get }
	var ssoOIDC: AWSSSOOIDC.SSOOIDCClient { get }
	func getRoleCredentials(input: AWSSSO.GetRoleCredentialsInput) async -> Result<AWSSSO.GetRoleCredentialsOutput, Error>
	func startDeviceAuthorization(input: AWSSSOOIDC.StartDeviceAuthorizationInput) async -> Result<AWSSSOOIDC.StartDeviceAuthorizationOutput, Error>
	func listAccounts(input: AWSSSO.ListAccountsInput) async -> Result<AWSSSO.ListAccountsOutput, Error>
	func listAccountRoles(input: AWSSSO.ListAccountRolesInput) async -> Result<AWSSSO.ListAccountRolesOutput, Error>
	func registerClient(input: AWSSSOOIDC.RegisterClientInput) async -> Result<AWSSSOOIDC.RegisterClientOutput, Error>
	func createToken(input: AWSSSOOIDC.CreateTokenInput) async -> Result<AWSSSOOIDC.CreateTokenOutput, Error>
}

class AWSSSOSDKProtocolWrappedImpl: AWSSSOSDKProtocolWrapped {
	let ssoRegion: String
	let sso: AWSSSO.SSOClient
	let ssoOIDC: AWSSSOOIDC.SSOOIDCClient

	init(ssoRegion: String) throws {
		self.ssoRegion = ssoRegion
		self.sso = try AWSSSO.SSOClient(region: self.ssoRegion)
		self.ssoOIDC = try AWSSSOOIDC.SSOOIDCClient(region: self.ssoRegion)
	}

	func getRoleCredentials(input: AWSSSO.GetRoleCredentialsInput) async -> Result<AWSSSO.GetRoleCredentialsOutput, Error> {
		return await Result.X { try await self.sso.getRoleCredentials(input: input) }
	}

	func startDeviceAuthorization(input: AWSSSOOIDC
		.StartDeviceAuthorizationInput) async -> Result<AWSSSOOIDC.StartDeviceAuthorizationOutput, Error>
	{
		return await Result.X { try await self.ssoOIDC.startDeviceAuthorization(input: input) }
	}

	func listAccounts(input: AWSSSO.ListAccountsInput) async -> Result<AWSSSO.ListAccountsOutput, Error> {
		return await Result.X { try await self.sso.listAccounts(input: input) }
	}

	func listAccountRoles(input: AWSSSO.ListAccountRolesInput) async -> Result<AWSSSO.ListAccountRolesOutput, Error> {
		return await Result.X { try await self.sso.listAccountRoles(input: input) }
	}

	func registerClient(input: AWSSSOOIDC.RegisterClientInput) async -> Result<AWSSSOOIDC.RegisterClientOutput, Error> {
		return await Result.X { try await self.ssoOIDC.registerClient(input: input) }
	}

	func createToken(input: AWSSSOOIDC.CreateTokenInput) async -> Result<AWSSSOOIDC.CreateTokenOutput, Error> {
		return await Result.X { try await self.ssoOIDC.createToken(input: input) }
	}
}

public func buildAWSSSOSDKProtocolWrapped(ssoRegion: String) -> Result<AWSSSOSDKProtocolWrapped, Error> {
	return Result.X { try AWSSSOSDKProtocolWrappedImpl(ssoRegion: ssoRegion) }
}

public class SecureAWSSSOClientRegistrationInfo: NSObject, NSSecureCoding {
	public static let supportsSecureCoding: Bool = true

	let clientID: String
	let clientSecret: String

	init(clientID: String, clientSecret: String) {
		self.clientID = clientID
		self.clientSecret = clientSecret
	}

	private let clientIDKey = "clientId"
	private let clientSecretKey = "clientSecret"

	// MARK: - NSSecureCoding

	public required init?(coder: NSCoder) {
		guard let clientID = coder.decodeObject(of: NSString.self, forKey: clientIDKey) as String?,
		      let clientSecret = coder.decodeObject(of: NSString.self, forKey: clientSecretKey) as String?
		else {
			return nil
		}

		self.clientID = clientID
		self.clientSecret = clientSecret
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.clientID, forKey: self.clientIDKey)
		coder.encode(self.clientSecret, forKey: self.clientSecretKey)
	}

	static func fromAWS(_ input: AWSSSOOIDC.RegisterClientOutput) -> Result<SecureAWSSSOClientRegistrationInfo, Error> {
		if let clientID = input.clientId, let clientSecret = input.clientSecret {
			return .success(SecureAWSSSOClientRegistrationInfo(clientID: clientID, clientSecret: clientSecret))
		}
		return .failure(x.error("missing values"))
	}
}
