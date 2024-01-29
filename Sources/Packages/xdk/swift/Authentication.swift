import Foundation

public protocol AuthenticationAPI {
	func obtainAuthentication(reason: String) async -> Result<Bool, Error>
	func authenticationAvailable() -> Result<Bool, Error>
}

func ObtainAuthentication(using: AuthenticationAPI, reason: String) async -> Result<Bool, Error> {
	return await using.obtainAuthentication(reason: reason)
}

func AuthenticationAvailable(using: AuthenticationAPI) -> Result<Bool, Error> {
	return using.authenticationAvailable()
}

public class NoopAuthentication: AuthenticationAPI {
	public func obtainAuthentication(reason _: String) async -> Result<Bool, Error> {
		return .success(true)
	}

	public func authenticationAvailable() -> Result<Bool, Error> {
		return .success(true)
	}

	public init() {}
}
