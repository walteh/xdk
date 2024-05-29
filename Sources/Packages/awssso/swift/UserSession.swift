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
	public let account: AccountInfo
	public let webview: WKWebView

	public let rebuildURL: () async -> Void

	public init(webview: WKWebView, session: AWSSSOUserSession, storageAPI: some XDK.StorageAPI, account: AccountInfo) {
		self.webview = webview
		self.managedRegion = session
		self.account = account
		self.rebuildURL = {
			var err: Error? = nil


			guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: session.accessToken!.region).to(&err) else {
				XDK.Log(.error).err(err).send("error generating console url")
				return
			}

			guard let url = await XDKAWSSSO.generateAWSConsoleURL(client: awsClient, account: account, managedRegion: session, storageAPI: storageAPI, accessToken: session.accessToken!).to(&err) else {
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
// https://us-east-1.signin.aws.amazon.com/federation?Action=getSigninToken&sessionDuration=3200&Session=%7B%22sessionToken%22:%22IQoJb3JpZ2luX2VjEJP__________wEaCXVzLWVhc3QtMSJHMEUCIQCoEp_Fz4xKByFeAAFyEiSbnP5GpYeSTGVIJ8Q-cQHLlQIgP4v_n1q_81T5KdoUUAV9O6HURzP6KEPi55e-_8fTd48qwwMIGxAAGgw4NjAwNzg3NTI5MTUiDJ28J1j4pui2AKQ-7iqgA3JlCxcLUZCDrDCcPcc7pe2FUKJPLwxfUPzQXh0vR1bd6m90TN1koZi7_w0IIC6TYShbTeivMcTOG36xCiidglzJPXtuXdsO-gcSp7SHpLsGKT3K91uUbYMEse-wEegWkPwzkXFjFXvu1FKCvGYCS50TMgedFXc6NT3g9FfWQ20v9EuJ_YZVV9N81dPWHHL4t5NzPy9glSp4JtQo4MYWt8mk-VnFqF-P3vDU2Qem_SOaShyw85P1nPbqFK6ZytkSVxszC5-RDtZmO9bWsfx-W9ttaFPIwgrDvASj8xbbjWjZoodGOXQnHAR32MMB3OJKZLdiwN2uc9-znAO8dspzhbGLK70dlegOKYX5tCl4tXS8AL_I_zLY-tINHz4H15h9dpCOxkxjvGVrC478kDbnRTIjvba5fSdUuKG6jWMqnHP2EVSV8ghzGcOKYuuD1FbUQZhZ182vRJciolI-8bcylIwV1BphFZbmCB2agBrOWAAHESCw8Z2zTHV-HbueWgy7ZTKzea8XHO31v3C38lpGPQUK1QueRq_PmP08R3MoWBCgMPvh3bIGOqYBFIf9RNPN_4S2SD26wbTu2SEjblm6Mofs2-jZzjMI7Y9VmGER34XptIAQvyVrtSqu8B5AldD1b-x_upq4MM70cmRhdk7an38dxpRwg5uVRxLtNtpg4TEkWu98QADro0ucAOk2k53mlRzyQFKppC_d7QIWsfAyathRVUg5z40n3N7ozP_wF3si_SABY1yE7k-QGCyyDfNvnRm068i2HOGOCTqkuB5Iuw%22,%22sessionId%22:%22ASIA4QQFQISJ5WXXPKQS%22,%22sessionKey%22:%22Mocc+pCDiPLC3bT0lBwUAfPt9B13HZ+84isxnMzK%22%7D

// https://us-east-1.signin.aws.amazon.com/federation?Action=login&Issuer=com.walteh.spatial-aws&Destination=https://us-east-1.console.aws.amazon.com/console/home?region%3Dus-east-1&SigninToken=fhlgPIrJcvBT1liYm3wxh2uKlHr3su-f_E4oN_Za5A2YCaoxBZcC1y7kpM6sobBi3eElZZt-V4fvmimVR6uP-4hZ-MNVICKVmHrPTju6xRy6Bpdi9Zqul_NzQc8Qn1aAPJGIRu6ujRuOKmIzVxE3ZdRVPvOoMkeJXZXeSqJ9WHjuZXpx-MfId48pXxkBxXJ_ieniAE77xwMfBIRYBel0o7UDVmZ35HBpoVLhcdWHC5OVBcSW8BnpFKHvZ8tQj-vvXRP8yPJg3oVEModK7Q3ajH85jEPV62Aogf1rhPiJRS-kLtocJzqYYPDszZ_zwAB8SRlZxmw-7uHw2FKQwyMY9nx0fhyrCo9ZQ_paf531NWJS_61E75bm4clCL_gTPR4PUzQHo2daaCtDd2odXhBIMrgSNfIM1O0OoiupzlGvSPDP0dWWK2YRvHBCdR2H7t65I54ttsN3TO9Q2h8uOmCxqAF_BXEsMBhHukKod1hbAuQ3JYCELX5HkE0Hi-BMSkq4wJp_qMdF023RouRqFVuaMeIirskPEjRw7ostcA_WtenUVz1LIA9j7W87823PVX5ijFIdEsbXJrJEdB0kG7kWTf0nFiYOEFFJCsGj2gh8_i1N7ahO_yupWMN9GiXbtStd5zWSGW0pk_K6l56jAh9PjrQXkqjgMuGwNsA9t7vQBnTkzldUCe8U-8NH2Vrj-tKyjAoWUflGW30_ETR8LlHLrSec03GD7N9m7Y0LBqPLqAARapy7f7Bgv-UPWzJGYFpggmEAj2kniL_NoRgGTvkYz9A_cr5avEVpMcDPpRNJy2yE4IAczP1Zx2pWEKh9u6503HU3xkor-rH1JbVZKlcUwaBcEcKdKdIAfYSkmffCWTUuiFu5VRO1CsE5oENA5mItVrKWv49uBkMcufOayR_fOviKPvpamkQLkB2dPWGZyDujE1jFWSLrMw_oNAVKAOBaoXkSTydpPT_R9pduZCL3i1K_WdVQYCUXQ3j-jxTId9obQGiq16i33Z0fiYuaRsftbfV6ZCkTJtnJr2YZ50EWvva8bZu7YuiSaaNivfv9wShSA9ltNQRIhNvBYcq5Zn4NAfctuZWwpPKWmGBcrbkgFB_AA_ZUpIZ6Bf4tSk8_TS0EUg-Bc60iiz_MYuD7o5EOXVH6V4sUypQSypJWFOXPWLL4sebAuMxJSRq66vm5XjKAJ_8J-NkP5rm_Llcoxd6qhPVuU3yS4bao_WmdPvTy5Mst59t9fpK6oRsyjiwb6rfbc4dTgARJ2ipVfxpF5T2goCi5fNSLK6VVopSn6zHjL-eOcLEHIX4rRBzS46VgfHLojTJj-l6OcBvcdYw1F2ZLRdJlf0nqwtm9SE0S9rS5QKFJNln_mlSWc-begxEoPEo_GiqeRbVJ1xAmr-Kq4S6uS7QY_XKUppVkf1v5ZHlAXIe5zQvgqHMSerLGzBGX4DrrpmbcxwvwlvuGg3Qwvb4ZNqY2GL90kP_E577xnpTy4_gcSQ_wejHRGcU98q2phHzzseixl-Dns-GFx4UG2nb0H1iuGsxYbIR5qRudAEnO-OxEvPtNEsQpEvVBmCtOBMeKClndBqZvCzpcL0s_KZGQfAnk27aTAP0QW-rcvOkNsmx7RWV44Dy6zXBQVsuJa57cOsoDR8btyDHXfrTsZXPFaRQN88_z-n_-O4V1PCwxXH7pcVn2y4Al-GFQn3ZlCkJT04fM5dlsi8rr4mSofYq7LJY7k2aXv8-rkQ2LQdJWI5FlocbM9w
public class AWSSSOUserSession: ObservableObject, ManagedRegion {
	public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { self.$accessToken }
	@Published public var accessToken: SecureAWSSSOAccessToken? = nil
//	@Published public var awsClient: AWSClient
//	@Published public var ssooidcClient: SSOOIDCClient? = nil
	@Published public var accountsList: AccountInfoList = .init(accounts: [])

	@Published public var accounts: [AccountInfo: Viewer] = [:]


	@Published public var region: String?  {
		didSet {
			DispatchQueue.main.async {
				for (_, viewer) in self.accounts {
					Task {
						await viewer.rebuildURL()
					}
				}
			}
		}
	}

	@Published public var service: String? = nil {
		didSet {
			DispatchQueue.main.async {
				for (_, viewer) in self.accounts {
					Task {
						await viewer.rebuildURL()
					}
				}
			}
		}
	}

	let storageAPI: any XDK.StorageAPI

	@Published public var currentAccount: AccountInfo? = nil

	public var currentWebview: WKWebView {
		if let currentAccount {
			if let wk = self.accounts[currentAccount] {
				return wk.webview
			} else {
				let viewer = Viewer(webview: createWebView(), session: self, storageAPI: self.storageAPI, account: currentAccount)
				self.accounts[currentAccount] = viewer
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

func constructFederationURLRequest(with credentials: RoleCredentials) -> Result<URLRequest, Error> {
	var err: Error? = nil

	let federationBaseURL = credentials.stsRegion.starts(with: "us-gov-") ?
		"https://signin.amazonaws-us-gov.com/federation" :
	"https://\(credentials.stsRegion).signin.aws.amazon.com/federation"

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

	guard let request = constructFederationURLRequest(with: credentials).to(&err) else {
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

	guard let request = constructFederationURLRequest(with: credentials).to(&err) else {
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
