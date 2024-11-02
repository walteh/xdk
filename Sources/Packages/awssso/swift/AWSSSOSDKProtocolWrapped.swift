import AWSSSO
import AWSSSOOIDC
import Combine
import Err
import Foundation
import XDK

public protocol AWSSSOSDKProtocolWrapped: Sendable {
	var ssoRegion: String { get }
	var sso: AWSSSO.SSOClient { get }
	var ssoOIDC: AWSSSOOIDC.SSOOIDCClient { get }
	func getRoleCredentials(
		input: AWSSSO.GetRoleCredentialsInput
	) async -> Result<
		AWSSSO.GetRoleCredentialsOutput, Error
	>
	func startDeviceAuthorization(
		input: AWSSSOOIDC.StartDeviceAuthorizationInput
	) async -> Result<
		AWSSSOOIDC.StartDeviceAuthorizationOutput, Error
	>
	func listAccounts(
		input: AWSSSO.ListAccountsInput
	) async -> Result<
		AWSSSO.ListAccountsOutput, Error
	>
	func listAccountRoles(
		input: AWSSSO.ListAccountRolesInput
	) async -> Result<
		AWSSSO.ListAccountRolesOutput, Error
	>
	func registerClient(
		input: AWSSSOOIDC.RegisterClientInput
	) async -> Result<
		AWSSSOOIDC.RegisterClientOutput, Error
	>
	func createToken(
		input: AWSSSOOIDC.CreateTokenInput
	) async -> Result<
		AWSSSOOIDC.CreateTokenOutput, Error
	>
}

extension AWSSSO.ListAccountsOutput: @retroactive @unchecked Sendable {}
extension AWSSSO.ListAccountRolesOutput: @retroactive @unchecked Sendable {}
extension AWSSSOOIDC.StartDeviceAuthorizationOutput: @retroactive @unchecked Sendable {}
extension AWSSSOOIDC.RegisterClientOutput: @retroactive @unchecked Sendable {}
extension AWSSSOOIDC.CreateTokenOutput: @retroactive @unchecked Sendable {}

class AWSSSOSDKProtocolWrappedImpl: AWSSSOSDKProtocolWrapped, @unchecked Sendable {
	let ssoRegion: String
	let sso: AWSSSO.SSOClient
	let ssoOIDC: AWSSSOOIDC.SSOOIDCClient

	init(ssoRegion: String) throws {
		self.ssoRegion = ssoRegion
		self.sso = try AWSSSO.SSOClient(region: self.ssoRegion)
		self.ssoOIDC = try AWSSSOOIDC.SSOOIDCClient(region: self.ssoRegion)
	}

	func getRoleCredentials(
		input: AWSSSO.GetRoleCredentialsInput
	) async -> Result<
		AWSSSO.GetRoleCredentialsOutput, Error
	> {
		await Result { try await self.sso.getRoleCredentials(input: input) }
	}

	func startDeviceAuthorization(
		input: AWSSSOOIDC.StartDeviceAuthorizationInput
	) async -> Result<
		AWSSSOOIDC.StartDeviceAuthorizationOutput, Error
	> {
		await Result { try await self.ssoOIDC.startDeviceAuthorization(input: input) }
	}

	func listAccounts(
		input: AWSSSO.ListAccountsInput
	) async -> Result<
		AWSSSO.ListAccountsOutput, Error
	> {
		await Result { try await self.sso.listAccounts(input: input) }
	}

	func listAccountRoles(
		input: AWSSSO.ListAccountRolesInput
	) async -> Result<
		AWSSSO.ListAccountRolesOutput, Error
	> {
		await Result { try await self.sso.listAccountRoles(input: input) }
	}

	func registerClient(
		input: AWSSSOOIDC.RegisterClientInput
	) async -> Result<
		AWSSSOOIDC.RegisterClientOutput, Error
	> {
		await Result { try await self.ssoOIDC.registerClient(input: input) }
	}

	func createToken(
		input: AWSSSOOIDC.CreateTokenInput
	) async -> Result<
		AWSSSOOIDC.CreateTokenOutput, Error
	> {
		await Result { try await self.ssoOIDC.createToken(input: input) }
	}
}

public func buildAWSSSOSDKProtocolWrapped(
	ssoRegion: String
) -> Result<
	AWSSSOSDKProtocolWrapped, Error
> {
	return Result { try AWSSSOSDKProtocolWrappedImpl(ssoRegion: ssoRegion) }
}

public struct SecureAWSSSOClientRegistrationInfo: Codable, Sendable {
	let clientID: String
	let clientSecret: String

	init(clientID: String, clientSecret: String) {
		self.clientID = clientID
		self.clientSecret = clientSecret
	}

	static func fromAWS(
		_ input: AWSSSOOIDC.RegisterClientOutput
	) -> Result<
		SecureAWSSSOClientRegistrationInfo, Error
	> {
		if let clientID = input.clientId, let clientSecret = input.clientSecret {
			return .success(
				SecureAWSSSOClientRegistrationInfo(clientID: clientID, clientSecret: clientSecret)
			)
		}
		return .failure(error("missing values"))
	}
}
