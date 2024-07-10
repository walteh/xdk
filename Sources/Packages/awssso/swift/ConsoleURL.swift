import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK

public func generateAWSConsoleURLWithDefaultClient(
	account: AccountInfo,
	role: RoleInfo,
	managedRegion: ManagedRegionService,
	storageAPI: some XDK.StorageAPI,
	accessToken: SecureAWSSSOAccessToken,
	isSignedIn: Bool
) async -> Result<URL, Error> {
	var err = Error?.none

	guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.region).to(&err) else {
		return .failure(XDK.Err("creating aws client", root: err))
	}

	return await generateAWSConsoleURL(
		client: awsClient,
		account: account,
		role: role,
		managedRegion: managedRegion,
		storageAPI: storageAPI,
		accessToken: accessToken,
		isSignedIn: isSignedIn
	)
}

public func generateAWSConsoleURL(
	client: AWSSSOSDKProtocolWrapped,
	account: AccountInfo,
	role: RoleInfo,
	managedRegion: ManagedRegionService,
	storageAPI: some XDK.StorageAPI,
	accessToken: SecureAWSSSOAccessToken,
	isSignedIn: Bool,
	retryNumber: Int = 0
) async -> Result<URL, Error> {
	var err: Error? = nil

	//	guard let role = account.role else {
	//		return .failure(x.error("role not set"))
	//	}

	let region = managedRegion.region ?? accessToken.region
	let service = managedRegion.service ?? ""

	guard let creds = await getRoleCredentials(client, storage: storageAPI, accessToken: accessToken, account: role).to(&err) else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	// if creds were updated, we need a new signintoken
	if creds.pulledFromCache, isSignedIn {
		XDK.Log(.debug).send("role creds were pulled from cache, but user is signed in")
		return constructSimpleConsoleURL(region: region, service: service)
	}

	guard let signInTokenResult = await fetchSignInToken(with: creds.data, retryNumber: -1).to(&err) else {
		if retryNumber < 5 {
			XDK.Log(.debug).err(err).add("count", any: retryNumber).send("retrying generateAWSConsoleURL")

			guard let _ = invalidateRoleCredentials(storageAPI, account: role).to(&err) else {
				return .failure(x.error("error invalidating role creds", root: err))
			}

			return await generateAWSConsoleURL(
				client: client,
				account: account,
				role: role,
				managedRegion: managedRegion,
				storageAPI: storageAPI,
				accessToken: accessToken,
				isSignedIn: false, // regardless of what our caller thinks we need to log in again
				retryNumber: retryNumber + 1
			)
		}

		return .failure(XDK.Err("error fetching signInToken", root: err))
	}

	guard let consoleHomeURL = constructLoginURL(with: signInTokenResult, credentials: creds.data, region: region, service: service).to(&err) else {
		return .failure(XDK.Err("error constructing console url", root: err))
	}

	return .success(consoleHomeURL)
}

func constructFederationURLRequest(with credentials: RoleCredentials) -> Result<URLRequest, Error> {
	let federationBaseURL = credentials.stsRegion.starts(with: "us-gov-") ?
		"https://signin.amazonaws-us-gov.com/federation" :
		"https://\(credentials.stsRegion).signin.aws.amazon.com/federation"

	// log out secretAccessKey and sessionToken
	XDK.Log(.debug).info("accessKeyID", credentials.accessKeyID).info("secretAccessKey", credentials.secretAccessKey).info("sessionToken", credentials.sessionToken).send("constructing federation request")

	// https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_enable-console-custom-url.html#STSConsoleLink_manual
	let sessionStringJSON = """
	{
		"sessionId": "\(credentials.accessKeyID)",
		"sessionKey": "\(credentials.secretAccessKey.toggleBase64URLSafe(on: false))",
		"sessionToken": "\(credentials.sessionToken.toggleBase64URLSafe(on: true))"
	}
	"""

	var components = URLComponents(url: URL(string: federationBaseURL)!, resolvingAgainstBaseURL: false)!

	// the default encoding does not encode the potential "+" inside the sessionKey form above, so we need to do it manually
	components.percentEncodedQueryItems = [
		URLQueryItem(name: "Action", value: "getSigninToken".urlPercentEncoding()),
		URLQueryItem(name: "sessionDuration", value: "3200".urlPercentEncoding()),
		URLQueryItem(name: "Session", value: sessionStringJSON.urlPercentEncoding()),
	]
	var req = URLRequest(url: components.url!)
	req.httpMethod = "GET"
	req.addValue("en-US", forHTTPHeaderField: "accept-language")

	return .success(req)
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
			$0.add("components", components)
		})
	}
}
