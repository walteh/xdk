import AWSSSO
import AWSSSOOIDC
import Combine
import Foundation
import XDK
import Err

@err public func generateAWSConsoleURLWithDefaultClient(
	account: AccountInfo,
	role: RoleInfo,
	managedRegion: ManagedRegionService,
	storageAPI: some XDK.StorageAPI,
	accessToken: AccessToken,
	isSignedIn: Bool
) async -> Result<URL, Error> {


	guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.stsRegion()).get() else {
		return .failure(XDK.Err("creating aws client", root: err))
	}

	return await generateAWSConsoleURLUsingSSO(
		client: awsClient,
		account: account,
		role: role,
		managedRegion: managedRegion,
		storageAPI: storageAPI,
		accessToken: accessToken,
		isSignedIn: isSignedIn
	)
}

@err  public func generateAWSConsoleURLWithExpiryWithDefaultClient(
	account: AccountInfo,
	role: RoleInfo,
	managedRegion: ManagedRegionService,
	storageAPI: some XDK.StorageAPI,
	accessToken: AccessToken,
	isSignedIn: Bool
) async -> Result<(URL, Date), Error> {


	guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.stsRegion()).get() else {
		return .failure(XDK.Err("creating aws client", root: err))
	}

	return await generateAWSConsoleURLWithExpiry(
		client: awsClient,
		account: account,
		role: role,
		managedRegion: managedRegion,
		storageAPI: storageAPI,
		accessToken: accessToken,
		isSignedIn: isSignedIn
	)
}

@err public func generateAWSConsoleURLUsingSSO(
	client: AWSSSOSDKProtocolWrapped,
	account: AccountInfo,
	role: RoleInfo,
	managedRegion: ManagedRegionService,
	storageAPI: some XDK.StorageAPI,
	accessToken: AccessToken,
	isSignedIn: Bool,
	retryNumber: Int = 0
) async -> Result<URL, Error> {


	//	guard let role = account.role else {
	//		return .failure(x.error("role not set"))
	//	}

	let region = managedRegion.region ?? client.ssoRegion
	let service = managedRegion.service ?? ""

	guard let creds = await getRoleCredentialsUsing(sso: client, storage: storageAPI, accessToken: accessToken, role: role).get() else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	// if creds were updated, we need a new signintoken
	if creds.pulledFromCache, isSignedIn {
		XDK.Log(.debug).meta(["role": .string(role.roleName)]).send("role creds were pulled from cache, but user is signed in")
		return constructSimpleConsoleURL(region: region, service: service)
	}

	guard let signInTokenResult = await fetchSignInToken(with: creds.data, retryNumber: -1).get() else {
		if retryNumber < 5 {
			XDK.Log(.debug).err(err).add("count", any: retryNumber).send("retrying generateAWSConsoleURL")

			guard let _ = invalidateRoleCredentials(storageAPI, role: role).get() else {
				return .failure(x.error("error invalidating role creds", root: err))
			}

			return await generateAWSConsoleURLUsingSSO(
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

	guard let consoleHomeURL = constructLoginURL(with: signInTokenResult, credentials: creds.data, region: region, service: service).get() else {
		return .failure(XDK.Err("error constructing console url", root: err))
	}

	return .success(consoleHomeURL)
}

@err  public func generateAWSConsoleURLWithExpiry(
	client: AWSSSOSDKProtocolWrapped,
	account: AccountInfo,
	role: RoleInfo,
	managedRegion: ManagedRegionService,
	storageAPI: some XDK.StorageAPI,
	accessToken: AccessToken,
	isSignedIn: Bool,
	retryNumber: Int = 0
) async -> Result<(URL, Date), Error> {


	let region = managedRegion.region ?? client.ssoRegion
	let service = managedRegion.service ?? ""

	guard let creds = await getRoleCredentialsUsing(sso: client, storage: storageAPI, accessToken: accessToken, role: role).get() else {
		return .failure(x.error("error fetching role creds", root: err))
	}

	// if creds were updated, we need a new signintoken
	if creds.pulledFromCache, isSignedIn {
		guard let simp = constructSimpleConsoleURL(region: region, service: service).get() else {
			return .failure(x.error("constructing url", root: err))
		}

		return .success((simp, creds.data.expiresAt))
	}

	guard let signInTokenResult = await fetchSignInToken(with: creds.data, retryNumber: -1).get() else {
		if retryNumber < 5 {
			XDK.Log(.debug).err(err).add("count", any: retryNumber).send("retrying generateAWSConsoleURL")

			guard let _ = invalidateRoleCredentials(storageAPI, role: role).get() else {
				return .failure(x.error("error invalidating role creds", root: err))
			}

			return await generateAWSConsoleURLWithExpiry(
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

	guard let consoleHomeURL = constructLoginURL(with: signInTokenResult, credentials: creds.data, region: region, service: service).get() else {
		return .failure(XDK.Err("error constructing console url", root: err))
	}

	return .success((consoleHomeURL, creds.data.expiresAt))
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

@err func constructLoginURL(with signInToken: String, credentials: RoleCredentials, region: String, service: String?) -> Result<URL, Error> {


	guard let request = constructFederationURLRequest(with: credentials).get() else {
		return .failure(x.error("error constructing federation url", root: err))
	}

	guard let consoleHomeURL = constructSimpleConsoleURL(region: region, service: service).get() else {
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
