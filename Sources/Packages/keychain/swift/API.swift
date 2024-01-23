//
//  API.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation
import XDKX

public protocol KeychainAPI {
	func read(insecurly key: String) -> Result<Data?, Error>
	func write(insecurly key: String, overwriting: Bool, as value: Data) -> Error?
	func withAuthentication() async -> Result<Bool, Error>
	func authenticationAvailable() -> Bool
}

public extension KeychainAPI {
	func read<T>(objectType _: T.Type, id: String) -> Result<T?, Error> where T: NSObject, T: NSSecureCoding {
		let _data = self.read(insecurly: "\(T.description())_\(id)")
		guard let data = _data.value else { return .failure(_data.error!) }
		guard let data else { return .success(nil) }
		return Result.X { try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data) }
	}

	func write<T>(object: T, overwriting: Bool, id: String) -> Error? where T: NSObject, T: NSSecureCoding {
		let _resp = Result.X { try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) }
		guard let resp = _resp.value else { return _resp.error! }
		return self.write(insecurly: "\(T.description())_\(id)", overwriting: overwriting, as: resp)
	}
}

public enum KeychainError: Swift.Error {
	case unhandled(status: OSStatus)
	case readCredentials__SecItemCopyMatching__ItemNotFound
	case addCredentials__SecItemAdd__SecAuthFailed
	case duplicate_item
	case auth_failed
	case auth_approved_but_no_value_found
	case auth_request_denied_by_user
	case no_auth_saved
	case auth_already_saved
	case evalutePolicy_returned_nothing
	case cannot_create_address_from_compressed_key
	case errSecParam
}
