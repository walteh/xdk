//
//  AWSSSO.swift
//
//  Created by walter on 1/21/24.
//

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK
import XDKKeychain

public protocol AWSSSOUserSessionAPI: ObservableObject {
	var accessToken: SecureAccessToken? { get set }
	var account: AccountRole? { get }
	var region: String? { get }
	var service: String? { get }

	var accessTokenPublisher: Published<SecureAccessToken?>.Publisher { get }
}

public class AWSSSOUserSession: ObservableObject, AWSSSOUserSessionAPI {
	@Published public var isSignedIn = false // This will be toggled when sign-in is successful

	@Published public var account: AccountRole? = nil
	@Published public var region: String? = nil
	@Published public var service: String? = nil
	@Published public var resource: String? = nil

	public init(account: AccountRole? = nil, region: String? = nil, service: String? = nil, resource: String? = nil, accessToken: SecureAccessToken? = nil) {
		self.account = account
		self.region = region
		self.service = service
		self.accessToken = accessToken
		self.resource = resource
	}

	@Published public var accessToken: SecureAccessToken? {
		didSet {
			if let newToken = accessToken, newToken != oldValue {
				self.updateAccountsList()
			}
		}
	}

	public var accessTokenPublisher: Published<SecureAccessToken?>.Publisher { self.$accessToken }

	// updates automatically when the user signs in
	@Published public var accounts: [AccountRole] = []

	private func updateAccountsList() {
		guard let accessToken else { return }

		Task {
			let _client = Result.X { try AWSSSO.SSOClient(region: accessToken.region) } // specify the correct region
			guard let client = _client.value else {
				print("error creating client \(_client.error!)")
				return
			}
			let result = await listAccounts(client, accessToken: accessToken)
			DispatchQueue.main.async {
				switch result {
				case let .success(fetchedAccounts):
					self.accounts = fetchedAccounts
				case let .failure(error):
					print("Error fetching accounts: \(error)")
				}
			}
		}
	}
}

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

public struct AccountRole: Hashable, Equatable {
	public let accountID: String
	public let role: String

	var name: String {
		return "\(self.accountID) - \(self.role)"
	}

	init(accountID: String, role: String) {
		self.accountID = accountID
		self.role = role
	}

	func getCreds(_ client: AWSSSO.SSOClient, storageAPI: some StorageAPI, accessToken: SecureAccessToken) async -> Result<RoleCredentials, Error> {
		var err: Error? = nil

		guard let curr = XDK.Read(using: storageAPI, RoleCredentials.self, differentiator: self.name).to(&err) else {
			return .failure(x.error("error reading role creds from keychain", root: err))
		}

		// dereference err1

		if let curr {
			if curr.expiresIn() > 60 * 5, curr.expiresIn() < 60 * 60 * 24 * 7 {
				XDK.Log(.debug).info("creds", curr.accessKeyID).info("account", self.accountID).info("role", self.role).info("expiresAt", curr.expiresAt).send("using cached creds")
				return .success(curr)
			}
		}

		// into this at compile time
		guard let creds = await Result.X({ try await client.getRoleCredentials(input: .init(accessToken: accessToken.accessToken, accountId: self.accountID, roleName: self.role)) }).to(&err) else {
			return .failure(x.error("error fetching role creds", root: err))
		}

		guard let rolecreds = creds.roleCredentials else {
			return .failure(x.error("roleCredentials does not exist"))
		}

		XDK.Log(.info).info("sessioTokenFromAWS", rolecreds.sessionToken).info("account", self.accountID).info("role", self.role).send("fetched role creds")

		let rcreds = RoleCredentials(rolecreds)

		XDK.Log(.debug).info("savedSessionToken", rcreds.sessionToken).info("account", self.accountID).info("role", self.role).send("saving role creds")

		guard let _ = XDK.Write(using: storageAPI, rcreds, overwrite: true, differentiator: self.name).to(&err) else {
			return .failure(x.error("error writing role creds to keychain", root: err))
		}

		XDK.Log(.debug).info("creds", rcreds.accessKeyID).info("account", self.accountID).info("role", self.role).info("expiresAt", rcreds.expiresAt).send("cached creds")

		return .success(rcreds)
	}
}

struct SessionData: Encodable {
	var Action: String
	var sessionDuration: Int
	var Session: SessionInfo
}

struct SessionInfo: Encodable {
	var sessionId: String
	var sessionKey: String
	var sessionToken: String
}

public struct UserSignInData: Equatable {
	public let activationURL: URL
	public let activationURLWithCode: URL
	public let code: String

	static func fromAWS(_ input: AWSSSOOIDC.StartDeviceAuthorizationOutput) -> UserSignInData {
		return UserSignInData(activationURL: URL(string: input.verificationUri!)!, activationURLWithCode: URL(string: input.verificationUriComplete!)!, code: input.deviceCode!)
	}
}

public class SecureClientRegistrationInfo: NSObject, NSSecureCoding {
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

	static func fromAWS(_ input: AWSSSOOIDC.RegisterClientOutput) -> Result<SecureClientRegistrationInfo, Error> {
		if let clientID = input.clientId, let clientSecret = input.clientSecret {
			return .success(SecureClientRegistrationInfo(clientID: clientID, clientSecret: clientSecret))
		}
		return .failure(x.error("missing values"))
	}
}

public class SecureAccessToken: NSObject, NSSecureCoding {
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

	static func fromAWS(input: AWSSSOOIDC.StartDeviceAuthorizationInput, output: AWSSSOOIDC.CreateTokenOutput, region: String) -> Result<SecureAccessToken, Error> {
		if let accessToken = output.accessToken, let startURL = input.startUrl {
			return .success(SecureAccessToken(
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

func listAccounts(_ client: AWSSSO.SSOClient, accessToken: SecureAccessToken) async -> Result<[AccountRole], Error> {
	var err: Error? = nil

	guard let response = await Result.X { try await client.listAccounts(input: .init(accessToken: accessToken.accessToken)) }.to(&err) else {
		return .failure(x.error("error fetching accounts", root: err))
	}

	var accounts = [AccountRole]()
	guard let accountList = response.accountList else {
		return .failure(x.error("response.accountList does not exist"))
	}
	// Iterate over accounts and fetch roles for each
	for account in accountList {
		guard let roles = await listRolesForAccount(client, accessToken: accessToken, accountID: account.accountId!).to(&err) else {
			return .failure(x.error("error fetching roles for account", root: err))
		}
		for role in roles {
			accounts.append(role)
		}
	}

	return .success(accounts)
}

func listRolesForAccount(_ client: AWSSSO.SSOClient, accessToken: SecureAccessToken, accountID: String) async -> Result<[AccountRole], Error> {
	// List roles for the given account
	let _rolesResponse = await Result.X {
		try await client.listAccountRoles(input: .init(accessToken: accessToken.accessToken, accountId: accountID))
	}
	guard let rolesResponse = _rolesResponse.value else { return .failure(_rolesResponse.error!) }

	var roles = [AccountRole]()
	if let roleList = rolesResponse.roleList {
		for role in roleList {
			roles.append(AccountRole(accountID: role.accountId!, role: role.roleName!))
		}
	} else {
		return .failure(x.error("No roles found for account"))
	}

	return .success(roles)
}

public func loadAWSConsole(userSession: any AWSSSOUserSessionAPI, storageAPI: some XDK.StorageAPI) async -> Result<URL, Error> {
	var err: Error? = nil

	guard let account = userSession.account else {
		return .failure(x.error("Account not set"))
	}

	guard let region = userSession.region else {
		return .failure(x.error("Region not set"))
	}

	guard let accessToken = userSession.accessToken else {
		return .failure(x.error("accessToken not set"))
	}

	x.log(.debug).send("A")

	guard let client = Result.X({ try AWSSSO.SSOClient(region: region) }).to(&err) else {
		return .failure(x.error("error creating client", root: err))
	}

	x.log(.debug).send("B")

	guard let creds = await account.getCreds(client, storageAPI: storageAPI, accessToken: accessToken).to(&err) else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	guard let federationURL = constructFederationURL(with: creds, region: region).to(&err) else {
		return .failure(x.error("Failed to construct federation URL", root: err))
	}

	x.log(.debug).send("D")

	guard let signInTokenResult = await fetchSignInToken(from: federationURL).to(&err) else {
		return .failure(XDK.Err("error fetching signInToken", root: err).info("url", federationURL))
	}

	x.log(.debug).add("sign in result", signInTokenResult).send("we right here")

	let consoleHomeURL = constructConsoleURL(from: userSession)!

	return constructLoginURL(with: signInTokenResult, federationURL: federationURL.url!, destinationURL: consoleHomeURL)
}

public func constructConsoleURL(from session: any AWSSSOUserSessionAPI) -> URL? {
	guard let service = session.service,
	      let region = session.region,
	      let account = session.account
	else {
		return nil
	}

	let consoleHomeURL = region.starts(with: "us-gov-") ?
		"https://console.amazonaws-us-gov.com" :
		"https://\(region).console.aws.amazon.com"

	let dest = consoleHomeURL + "/\(service.lowercased())/home?region=\(region)"

	// Construct the URL based on the service, region, and account
	// This is a simplified example and might need to be adjusted
	// let urlString = "https://\(region).console.aws.amazon.com/\(service.lowercased())/home?region=\(region)"
	return URL(string: dest)
}

func constructFederationURL(with credentials: RoleCredentials, region: String) -> Result<URLRequest, Error> {
	var err: Error? = nil

	let federationBaseURL = region.starts(with: "us-gov-") ?
		"https://signin.amazonaws-us-gov.com/federation" :
		"https://signin.aws.amazon.com/federation"

	guard let sessionStringJSON = Result.X({ try JSONEncoder().encode(SessionInfo(
		sessionId: credentials.accessKeyID,
		sessionKey: credentials.secretAccessKey,
		sessionToken: credentials.sessionToken.toggleBase64URLSafe(on: true)
	)) }).to(&err) else {
		return .failure(x.error("error encoding session info", root: err))
	}

	XDK.Log(.debug).add("sessionStringJSON", String(data: sessionStringJSON, encoding: .ascii)!).send("constructFederationURL")

	let queryItems = [
		URLQueryItem(name: "Action", value: "getSigninToken"),
		URLQueryItem(name: "sessionDuration", value: "3200"),
		URLQueryItem(name: "Session", value: String(data: sessionStringJSON, encoding: .utf8)!),
	]

	var components = URLComponents(url: URL(string: federationBaseURL)!, resolvingAgainstBaseURL: false)!
	components.queryItems = queryItems
	var req = URLRequest(url: components.url!)
	req.httpMethod = "GET"
	req.addValue("en-US", forHTTPHeaderField: "accept-language")
	return .success(req)
}

func fetchSignInToken(from url: URLRequest) async -> Result<String, Error> {
	var err: Error? = nil

	guard let (data, response) = await Result.X({ try await URLSession.shared.data(for: url) }).to(&err) else {
		return .failure(x.error("error fetching sign in token", root: err))
	}

	guard let httpResponse = response as? HTTPURLResponse else {
		return .failure(x.error("unexpected response type: \(response)"))
	}

	if httpResponse.statusCode != 200 {
		// add info but only the first 10 and last 10 chars
		let lastfirst = String(data: data, encoding: .utf8)!.prefix(10) + "..." + String(data: data, encoding: .utf8)!.suffix(10).replacingOccurrences(of: "\n", with: "")
		return .failure(x.error("unexpected error code: \(httpResponse.statusCode)").info("body", lastfirst))
	}

	guard let jsonResult = Result.X({ try JSONSerialization.jsonObject(with: data) as? [String: Any] }).to(&err) else {
		return .failure(x.error("error parsing json", root: err))
	}

	if jsonResult == nil {
		return .failure(x.error("no json data returned"))
	}

	if let signInToken = jsonResult!["SigninToken"] as? String {
		return .success(signInToken)
	} else {
		return .failure(x.error("error parsing json"))
	}
}

func constructLoginURL(with signInToken: String, federationURL: URL, destinationURL: URL) -> Result<URL, Error> {
	guard var components = URLComponents(url: federationURL, resolvingAgainstBaseURL: false) else {
		return .failure(x.error("unable to build url components").info("federationURL", federationURL))
	}

	components.queryItems = [
		URLQueryItem(name: "Action", value: "login"),
		URLQueryItem(name: "Issuer", value: "signin.aws.amazon.com"),
		URLQueryItem(name: "Destination", value: destinationURL.absoluteString),
		URLQueryItem(name: "SigninToken", value: signInToken),
	]

	if let url = components.url {
		return .success(url)
	} else {
		return .failure(x.error("coule not convert components to url").event {
			return $0.add("components", components)
		})
	}
}

private func pollForToken(_ client: AWSSSOOIDC.SSOOIDCClientProtocol, registration: SecureClientRegistrationInfo, deviceAuth: UserSignInData, pollInterval: TimeInterval, expirationTime: TimeInterval) async -> Result<AWSSSOOIDC.CreateTokenOutput, Error> {
	// Calculate the expiration time as a Date
	let expirationDate = Date().addingTimeInterval(expirationTime)

	while Date() < expirationDate {
		do {
			// Attempt to create a token
			let tokenOutput = try await client.createToken(input: .init(
				clientId: registration.clientID,
				clientSecret: registration.clientSecret,
				deviceCode: deviceAuth.code,
				grantType: "urn:ietf:params:oauth:grant-type:device_code"
			))
			// Success, return the token
			return .success(tokenOutput)
		} catch _ as AWSSSOOIDC.AuthorizationPendingException {
			// If the error is "AuthorizationPending", wait for the pollInterval and then try again
			print("SSO login still pending, continuing polling")
			try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
		} catch {
//			// For any other error, return failure
//			print("SSO login failed with error: \(error.localizedDescription)")
			return .failure(x.error("SSO Login failed", root: error))
		}
	}

	// If the loop exits because the expiration time is reached, return a timeout error
	return .failure(NSError(domain: "SSOService", code: -1, userInfo: [NSLocalizedDescriptionKey: "SSO login timed out"]))
}

private func registerClientIfNeeded(awsssoAPI: AWSSSOOIDC.SSOOIDCClientProtocol, storageAPI: some XDK.StorageAPI) async -> Result<SecureClientRegistrationInfo, Error> {
	// Check if client is already registered and saved in secure storage (Keychain)

	var err: Error? = nil

	guard let reg = XDK.Read(using: storageAPI, SecureClientRegistrationInfo.self).to(&err) else {
		return .failure(x.error("error loading client registration", root: err))
	}

	if let reg {
		return .success(reg)
	}

	let regClientInput = AWSSSOOIDC.RegisterClientInput(clientName: "spatial-aws-basic", clientType: "public", scopes: [])

	// No registration found, register a new client
	guard let regd = await Result.X { try await awsssoAPI.registerClient(input: regClientInput) }.to(&err) else {
		return .failure(x.error("error registering client", root: err))
	}

	guard let work = SecureClientRegistrationInfo.fromAWS(regd).to(&err) else {
		return .failure(x.error("error creating secure client registration", root: err))
	}

	guard let _ = XDK.Write(using: storageAPI, work).to(&err) else {
		return .failure(x.error("error writing secure client registration", root: err))
	}

	return .success(work)
}

public func signInWithSSO(awsssoAPI: AWSSSOOIDC.SSOOIDCClientProtocol, storageAPI: some XDK.StorageAPI, ssoRegion: String, startURL: URL, callback: @escaping (_ url: UserSignInData) -> Void) async -> Result<SecureAccessToken, Error> {
	var err: Error? = nil

	guard let current = XDK.Read(using: storageAPI, SecureAccessToken.self).to(&err) else {
		return .failure(x.error("error loading access token", root: err))
	}

	if let current {
		if current.expiresAt.timeIntervalSince(Date().addingTimeInterval(5.0 * 60 * -1)) > 0.0 {
			return .success(current)
		}
	}

	guard let registration = await registerClientIfNeeded(awsssoAPI: awsssoAPI, storageAPI: storageAPI).to(&err) else {
		return .failure(x.error("error registering client", root: err))
	}

	let input = AWSSSOOIDC.StartDeviceAuthorizationInput(clientId: registration.clientID, clientSecret: registration.clientSecret, startUrl: startURL.absoluteString)

	guard let deviceAuth = await Result.X { try await awsssoAPI.startDeviceAuthorization(input: input) }.to(&err) else {
		return .failure(x.error("error starting device auth", root: err))
	}

	let data = UserSignInData.fromAWS(deviceAuth)

	callback(data)

	guard let tok = await pollForToken(awsssoAPI, registration: registration, deviceAuth: data, pollInterval: 1.0, expirationTime: 60.0).to(&err) else {
		return .failure(x.error("error polling for token", root: err))
	}

	guard let work = SecureAccessToken.fromAWS(input: input, output: tok, region: ssoRegion).to(&err) else {
		return .failure(x.error("error creating secure access token", root: err))
	}

	guard let _ = XDK.Write(using: storageAPI, work).to(&err) else {
		return .failure(x.error("error writing secure access token", root: err))
	}

	return .success(work)
}
