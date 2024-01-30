//
//  AWSSSO.swift
//
//  Created by walter on 1/21/24.
//

import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import SwiftUI
import WebKit
import XDK

public protocol AWSSSOUserSessionAPI: ObservableObject {
	var accessToken: SecureAWSSSOAccessToken? { get set }
	var account: AccountRole? { get }
	var accounts: [AccountRole: AWSSSOAccountRoleSession] { get }
	var accountsList: [AccountRole] { get }
	var region: String? { get }
	var service: String? { get }

	func refresh(accessToken: SecureAWSSSOAccessToken?, storageAPI: any XDK.StorageAPI) async -> Result<Void, Error>

	// func refresh(_ storageAPI: any XDK.StorageAPI) async -> Result<Void, Error>

	var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { get }
}

public extension AWSSSOUserSessionAPI {
	func currentAccountRoleSession() -> AWSSSOAccountRoleSession? {
		guard let account = self.account else {
			return nil
		}

		return self.accounts[account]
	}
}

public class AWSSSOUserSession: ObservableObject, AWSSSOUserSessionAPI {
	@Published public var isSignedIn = false // This will be toggled when sign-in is successful

	@Published public var account: AccountRole? = nil
	@Published public var region: String? = nil
	@Published public var service: String? = nil
	// @Published public var resource: String? = nil

	public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { self.$accessToken }
	@Published public var accessToken: SecureAWSSSOAccessToken? = nil
	@Published public var ssoClient: SSOClient? = nil
	@Published public var accounts: [AccountRole: AWSSSOAccountRoleSession] = [:]
	@Published public var accountsList: [AccountRole] = []

	public init(account: AccountRole? = nil) {
		self.account = account
	}

	// public func refresh(_ storageAPI: any XDK.StorageAPI) async -> Result<Void, Error> {
	// 	var err: Error? = nil

	// 	for account in self.accounts.keys {
	// 		guard let url = await generateAWSConsoleURL(
	// 			session: self,
	// 			storageAPI: storageAPI
	// 		).to(&err) else {
	// 			return .failure(x.error("error generating console url", root: err))
	// 		}
	// 		DispatchQueue.main.async {
	// 			self.accounts[account]!.webview.load(URLRequest(url: url))
	// 		}
	// 	}

	// 	return .success(())
	// }

	public func refresh(accessToken: SecureAWSSSOAccessToken?, storageAPI _: XDK.StorageAPI) async -> Result<Void, Error> {
		var err: Error? = nil

		if let at = accessToken {
			self.accessToken = at
		}

		guard let accessToken = self.accessToken else {
			return .failure(x.error("accessToken not set"))
		}

		guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
			return .failure(x.error("error updating sso client", root: err))
		}

		guard let accounts = await listAccounts(client, accessToken: accessToken).to(&err) else {
			return .failure(x.error("error updating accounts", root: err))
		}

		DispatchQueue.main.async {
			for account in accounts {
				if self.accounts[account] == nil {
					self.accounts[account] = AWSSSOAccountRoleSession(account: account)
				}
			}

			for account in self.accounts.keys {
				if !accounts.contains(account) {
					self.accounts[account] = nil
				}
			}

			self.accessToken = accessToken
			self.ssoClient = client
			self.accountsList = accounts
		}

		// for account in self.accounts {
		// 	guard let _ = await account.value.refresh(self, storageAPI: storageAPI).to(&err) else {
		// 		return .failure(x.error("error refreshing account", root: err))
		// 	}
		// }

		// for account in self.accounts.keys {
		// 	guard let url = await generateAWSConsoleURL(
		// 		session: self,
		// 		storageAPI: storageAPI
		// 	).to(&err) else {
		// 		return .failure(x.error("error generating console url", root: err))
		// 	}
		// 	DispatchQueue.main.async {
		// 		self.accounts[account]!.webview.load(URLRequest(url: url))
		// 	}
		// }

		// for (_, account) in self.accounts {
		// 	guard let _ = await account.refresh(self, storageAPI: storageAPI).to(&err) else {
		// 		return .failure(x.error("error refreshing account", root: err))
		// 	}
		// }

		return .success(())
	}

	private func buildSSOClient(accessToken: SecureAWSSSOAccessToken) async -> Result<AWSSSO.SSOClient, Error> {
		var err: Error? = nil

		guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
			return .failure(x.error("error creating client", root: err))
		}

		return .success(client)
	}

	private func updateAccounts(accessToken: SecureAWSSSOAccessToken, client _: SSOClient) async -> Result<[AccountRole], Error> {
		var err: Error? = nil

		guard let client = self.ssoClient else {
			return .failure(x.error("awsSSO client not set"))
		}

		guard let fetchedAccounts = await listAccounts(client, accessToken: accessToken).to(&err) else {
			return .failure(x.error("problem fetching accounts", root: err))
		}

		return .success(fetchedAccounts)
	}
}

public class AWSSSOAccountRoleSession: ObservableObject {
	let accountRole: AccountRole

	@Published public var region: String? = nil
	@Published public var resource: String? = nil

	public let webview = WKWebView()

	public init(account: AccountRole) {
		self.accountRole = account
	}

	// public func refresh(_ userSession: any AWSSSOUserSessionAPI, storageAPI: any XDK.StorageAPI) async -> Result<Void, Error> {
	// 	var err: Error? = nil

	// 	guard let url = await generateAWSConsoleURL(
	// 		session: userSession,
	// 		storageAPI: storageAPI
	// 	).to(&err) else {
	// 		return .failure(x.error("error generating console url", root: err))
	// 	}

	// 	if let accessToken = userSession.accessToken {
	// 		guard let _ = self.configureCookies(accessToken: accessToken).to(&err) else {
	// 			return .failure(x.error("error configuring cookies", root: err))
	// 		}

	// 		await self.webview.load(URLRequest(url: url))
	// 	}

	// 	return .success(())
	// }

	func configureCookies(accessToken: SecureAWSSSOAccessToken) -> Result<Void, Error> {
		if let cookie = HTTPCookie(properties: [
			.domain: "aws.amazon.com",
			.path: "/",
			.name: "AWSALB", // Adjust the name based on the actual cookie name required by AWS
			.value: accessToken.accessToken,
			.secure: true,
			.expires: NSDate(timeIntervalSinceNow: 3600),
		]) {
			DispatchQueue.main.async {
				self.webview.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
			}
			return .success(())
		} else {
			return .failure(x.error("error creating cookie"))
		}
	}

	public func goto(_ userSession: any AWSSSOUserSessionAPI, storageAPI: any XDK.StorageAPI) async -> Result<Void, Error> {
		var err: Error? = nil

		guard let url = await XDKAWSSSO.generateAWSConsoleURL(session: userSession, storageAPI: storageAPI).to(&err) else {
			return .failure(x.error("error generating console url", root: err))
		}

		if let accessToken = userSession.accessToken {
			guard let _ = self.configureCookies(accessToken: accessToken).to(&err) else {
				return .failure(x.error("error configuring cookies", root: err))
			}

			await self.webview.load(URLRequest(url: url))
		}

		return .success(())
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

public func generateAWSConsoleURL(session: any AWSSSOUserSessionAPI, storageAPI: some XDK.StorageAPI, retry: Bool = false) async -> Result<URL, Error> {
	var err: Error? = nil

	guard let account = session.account else {
		return .failure(x.error("Account not set"))
	}

	guard let region = session.region else {
		return .failure(x.error("Region not set"))
	}

	guard let service = session.service else {
		return .failure(x.error("Service not set"))
	}

	guard let accessToken = session.accessToken else {
		return .failure(x.error("accessToken not set"))
	}

	guard let client = Result.X({ try AWSSSO.SSOClient(region: region) }).to(&err) else {
		return .failure(x.error("error creating client", root: err))
	}

	guard let creds = await getRoleCredentials(client, storageAPI: storageAPI, accessToken: accessToken, account: account).to(&err) else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	guard let signInTokenResult = await fetchSignInToken(with: creds, region: region).to(&err) else {
		if !retry {
			guard let _ = invalidateRoleCredentials(storageAPI, account: account).to(&err) else {
				return .failure(x.error("error invalidating role creds", root: err))
			}

			return await generateAWSConsoleURL(session: session, storageAPI: storageAPI, retry: true)
		}

		// guard let signInTokenResult = await fetchSignInToken(with: creds, region: region).to(&err) else {
		// 	return .failure(x.error("error fetching signInToken", root: err))
		// }

		return .failure(XDK.Err("error fetching signInToken", root: err))
	}

	guard let consoleHomeURL = constructLoginURL(with: signInTokenResult, credentials: creds, region: region, service: service).to(&err) else {
		return .failure(XDK.Err("error constructing console url", root: err))
	}

	return .success(consoleHomeURL)
}

func constructFederationURLRequest(with credentials: RoleCredentials, region: String) -> Result<URLRequest, Error> {
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

	XDK.Log(.debug).add("sessionStringJSON", String(data: sessionStringJSON, encoding: .ascii)!).send("constructFederationURLRequest")

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

func fetchSignInToken(with credentials: RoleCredentials, region: String) async -> Result<String, Error> {
	var err: Error? = nil

	guard let request = constructFederationURLRequest(with: credentials, region: region).to(&err) else {
		return .failure(x.error("error constructing federation url", root: err))
	}

	guard let (data, response) = await Result.X({ try await URLSession.shared.data(for: request) }).to(&err) else {
		return .failure(x.error("error fetching sign in token", root: err))
	}

	guard let httpResponse = response as? HTTPURLResponse else {
		return .failure(x.error("unexpected response type: \(response)"))
	}

	if httpResponse.statusCode != 200 {
		// add info but only the first 10 and last 10 chars
		let lastfirst = String(data: data, encoding: .utf8)!.prefix(10) + "..." + String(data: data, encoding: .utf8)!.suffix(10).replacingOccurrences(of: "\n", with: "")

		// try to refresh credentials

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

func constructLoginURL(with signInToken: String, credentials: RoleCredentials, region: String, service: String?) -> Result<URL, Error> {
	var err: Error? = nil

	guard let request = constructFederationURLRequest(with: credentials, region: region).to(&err) else {
		return .failure(x.error("error constructing federation url", root: err))
	}

	var consoleHomeURL = region.starts(with: "us-gov-") ?
		"https://console.amazonaws-us-gov.com" :
		"https://\(region).console.aws.amazon.com"

	if let service {
		consoleHomeURL = consoleHomeURL + "/\(service.lowercased())/home?region=\(region)"
	} else {
		consoleHomeURL = consoleHomeURL + "/home?region=\(region)"
	}

	guard var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
		return .failure(x.error("unable to build url components").info("federationURL", request.url!))
	}

	components.queryItems = [
		URLQueryItem(name: "Action", value: "login"),
		URLQueryItem(name: "Issuer", value: "signin.aws.amazon.com"),
		URLQueryItem(name: "Destination", value: consoleHomeURL),
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
