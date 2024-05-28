//
//  UserSession.swift
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

public protocol ManagedRegion {
	var region: String? { get set }
	var service: String? { get set }
}

public class Viewer: NSObject, ObservableObject, WKNavigationDelegate {
	public var currentURL: URL? = nil

	public let managedRegion: ManagedRegion
	public let webview: WKWebView

	public let rebuildURL: () async -> Void

	public init(webview: WKWebView, session: AWSSSOUserSession, storageAPI: some XDK.StorageAPI) {
		self.webview = webview
		self.managedRegion = session

		self.rebuildURL = {
			var err: Error? = nil

			guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: session.accessToken!.region).to(&err) else {
				XDK.Log(.error).err(err).send("error generating console url")
				return
			}

			guard let url = await XDKAWSSSO.generateAWSConsoleURL(client: awsClient, account: session.currentAccount!, managedRegion: session, storageAPI: storageAPI, accessToken: session.accessToken!).to(&err) else {
				XDK.Log(.error).err(err).send("error generating console url")
				return
			}
			guard let _ = session.configureCookies(accessToken: session.accessToken!, webview: webview).to(&err) else {
				XDK.Log(.error).err(err).send("error configuring cookies")
				return
			}
//			DispatchQueue.main.async {
			guard let _ = await webview.load(URLRequest(url: url)) else {
				XDK.Log(.error).send("error loading webview")
				return
			}
//			}
		}

		super.init()

		self.webview.navigationDelegate = self

		Task {
			await self.rebuildURL()
		}
	}

	// when the webview starts up
	public func webView(_ webview: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
		XDK.Log(.info).info("url", webview.url).send("webview navigation start")
	}

	public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
		XDK.Log(.info).info("url", self.webview.url).send("webview navigation navigation")

		self.currentURL = webView.url
	}

	public func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
		XDK.Log(.error).err(error).send("webview navigation error")

		// constructSimpleConsoleURL(region: session.region ?? session.accessToken?.region ?? "us-east-1", service: session.service)
	}
}

public class AWSSSOUserSession: ObservableObject, ManagedRegion {
	public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { self.$accessToken }
	@Published public var accessToken: SecureAWSSSOAccessToken? = nil
//	@Published public var awsClient: AWSClient
//	@Published public var ssooidcClient: SSOOIDCClient? = nil
	@Published public var accountsList: AccountInfoList = .init(accounts: [])

	@Published public var accounts: [AccountInfo: Viewer] = [:]

	@Published public var region: String?

	@Published public var service: String? = nil

	let storageAPI: any XDK.StorageAPI

	@Published public var currentAccount: AccountInfo? = nil

	public var currentWebview: WKWebView {
		if let currentAccount {
			if let wk = self.accounts[currentAccount] {
				return wk.webview
			} else {
				self.accounts[currentAccount] = Viewer(webview: createWebView(), session: self, storageAPI: self.storageAPI)
				return self.accounts[currentAccount]!.webview
			}
		}
		let wv = createWebView()
		// load google.com
		wv.load(URLRequest(url: URL(string: "https://www.google.com")!))
		return wv
	}

	public init(storageAPI: any XDK.StorageAPI, account: AccountInfo? = nil) {
		self.currentAccount = account
		self.storageAPI = storageAPI
	}

	public func refresh(accessToken: SecureAWSSSOAccessToken?, storageAPI: XDK.StorageAPI) async -> Result<Void, Error> {
		var err: Error? = nil

		guard let accessToken = accessToken ?? self.accessToken else {
			return .failure(x.error("accessToken not set"))
		}

		guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.region).to(&err) else {
			return .failure(x.error("creating aws client", root: err))
		}

		guard let accounts = await getAccountsRoleList(client: awsClient, storage: storageAPI, accessToken: accessToken).to(&err) else {
			return .failure(x.error("error updating accounts", root: err))
		}

		guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
			return .failure(x.error("error updating sso client", root: err))
		}

		guard let ssooidcClient = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: accessToken.region) }).to(&err) else {
			return .failure(x.error("error updating ssooidc client", root: err))
		}

		DispatchQueue.main.async {
			self.accessToken = accessToken
			self.accountsList = accounts
//			self.ssooidcClient = ssooidcClient
		}

		return .success(())
	}

	// 	public func initialize(accessToken: SecureAWSSSOAccessToken?, storageAPI: XDK.StorageAPI)  -> Result<Void, Error> {
	// 	var err: Error? = nil

	// 	guard let accessToken = accessToken ?? self.accessToken else {
	// 		return .failure(x.error("accessToken not set"))
	// 	}

	// 	guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
	// 		return .failure(x.error("error updating sso client", root: err))
	// 	}

	// 	guard let ssooidcClient = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: accessToken.region) }).to(&err) else {
	// 		return .failure(x.error("error updating ssooidc client", root: err))
	// 	}

	// 	DispatchQueue.main.async {
	// 		self.accessToken = accessToken
	// 		self.ssoClient = client
	// 		self.ssooidcClient = ssooidcClient
	// 		self.accountsList = accounts
	// 	}

	// 	return .success(())
	// }

	private func buildSSOClient(accessToken: SecureAWSSSOAccessToken) async -> Result<AWSSSO.SSOClient, Error> {
		var err: Error? = nil

		guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
			return .failure(x.error("error creating client", root: err))
		}

		return .success(client)
	}

	func configureCookies(accessToken: SecureAWSSSOAccessToken, webview: WKWebView) -> Result<Void, Error> {
		if let cookie = HTTPCookie(properties: [
			.domain: "aws.amazon.com",
			.path: "/",
			.name: "AWSALB", // Adjust the name based on the actual cookie name required by AWS
			.value: accessToken.accessToken,
			.secure: true,
			.expires: accessToken.expiresAt,
		]) {
			DispatchQueue.main.async {
				webview.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
			}
			return .success(())
		} else {
			return .failure(x.error("error creating cookie"))
		}
	}
}

public struct UserSignInData: Equatable {
	public let activationURL: URL
	public let activationURLWithCode: URL
	public let code: String

	static func fromAWS(_ input: AWSSSOOIDC.StartDeviceAuthorizationOutput) -> UserSignInData {
		return UserSignInData(activationURL: URL(string: input.verificationUri!)!, activationURLWithCode: URL(string: input.verificationUriComplete!)!, code: input.deviceCode!)
	}
}

public func buildSSOOIDCClient(region: String) async -> Result<AWSSSOOIDC.SSOOIDCClient, Error> {
	var err: Error? = nil

	guard let client = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: region) }).to(&err) else {
		return .failure(x.error("error creating client", root: err))
	}

	return .success(client)
}

public func generateAWSConsoleURL(client: AWSSSOSDKProtocolWrapped, account: AccountInfo, managedRegion: ManagedRegion, storageAPI: some XDK.StorageAPI, accessToken: SecureAWSSSOAccessToken, retry: Bool = false) async -> Result<URL, Error> {
	var err: Error? = nil

	guard let role = account.role else {
		return .failure(x.error("role not set"))
	}

	// guard let accessToken = session.accessToken else {
	// 	return .failure(x.error("accessToken not set"))
	// }

	let region = managedRegion.region ?? accessToken.region
	let service = managedRegion.service ?? ""

	guard let creds = await getRoleCredentials(client, storageAPI: storageAPI, accessToken: accessToken, account: role).to(&err) else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	guard let signInTokenResult = await fetchSignInToken(with: creds).to(&err) else {
		if !retry {
			guard let _ = invalidateRoleCredentials(storageAPI, account: role).to(&err) else {
				return .failure(x.error("error invalidating role creds", root: err))
			}

			XDK.Log(.debug).send("retrying generateAWSConsoleURL")

			return await generateAWSConsoleURL(client: client, account: account, managedRegion: managedRegion, storageAPI: storageAPI, accessToken: accessToken, retry: true)
		}

		return .failure(XDK.Err("error fetching signInToken", root: err))
	}

	guard let consoleHomeURL = constructLoginURL(with: signInTokenResult, credentials: creds, region: region, service: service).to(&err) else {
		return .failure(XDK.Err("error constructing console url", root: err))
	}

	return .success(consoleHomeURL)
}

func constructFederationURLRequest(with credentials: RoleCredentials, region: String) -> Result<URLRequest, Error> {
	var err: Error? = nil

	let federationBaseURL = credentials.stsRegion.starts(with: "us-gov-") ?
		"https://signin.amazonaws-us-gov.com/federation" :
		"https://\(region).signin.aws.amazon.com/federation"

	guard let sessionStringJSON = Result.X({ try JSONEncoder().encode([
		"sessionId": credentials.accessKeyID,
		"sessionKey": credentials.secretAccessKey,
		"sessionToken": credentials.sessionToken.toggleBase64URLSafe(on: true),
	]) }).to(&err) else {
		return .failure(x.error("error encoding session info", root: err))
	}

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

func fetchSignInToken(with credentials: RoleCredentials) async -> Result<String, Error> {
	var err: Error? = nil

	guard let request = constructFederationURLRequest(with: credentials, region: credentials.stsRegion).to(&err) else {
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

		return .failure(x.error("unexpected error code: \(httpResponse.statusCode)").info("body", lastfirst).info("url", request.url?.absoluteString ?? "none"))
	}

	guard let jsonResult = Result.X({ try JSONSerialization.jsonObject(with: data) as? [String: Any] }).to(&err) else {
		return .failure(x.error("error parsing json", root: err))
	}

	if jsonResult == nil {
		return .failure(x.error("no json data returned"))
	}

	XDK.Log(.debug).info("jsonResult", jsonResult!).send("fetchSignInToken")

	if let signInToken = jsonResult!["SigninToken"] as? String {
		return .success(signInToken)
	} else {
		return .failure(x.error("error parsing json"))
	}
}

func constructSimpleConsoleURL(region: String, service: String? = nil) -> Result<URL, Error> {
	var consoleHomeURL = region.starts(with: "us-gov-") ?
		"https://console.amazonaws-us-gov.com" :
		"https://\(region).console.aws.amazon.com"

	if service == nil || service == "" {
		consoleHomeURL = consoleHomeURL + "/console/home?region=\(region)"
	} else {
		consoleHomeURL = consoleHomeURL + "/\(service!.lowercased())/home?region=\(region)"
	}

	guard let url = URL(string: consoleHomeURL) else {
		return .failure(x.error("error constructing console url"))
	}

	return .success(url)
}

func constructLoginURL(with signInToken: String, credentials: RoleCredentials, region: String, service: String?) -> Result<URL, Error> {
	var err: Error? = nil

	guard let request = constructFederationURLRequest(with: credentials, region: region).to(&err) else {
		return .failure(x.error("error constructing federation url", root: err))
	}

	guard let consoleHomeURL = constructSimpleConsoleURL(region: region, service: service).to(&err) else {
		return .failure(x.error("error constructing console url", root: err))
	}

	guard var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
		return .failure(x.error("unable to build url components").info("federationURL", request.url!))
	}

	components.queryItems = [
		URLQueryItem(name: "Action", value: "login"),
		URLQueryItem(name: "Issuer", value: "\(Bundle.main.bundleIdentifier ?? "XDK")"),
		URLQueryItem(name: "Destination", value: consoleHomeURL.absoluteString),
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
