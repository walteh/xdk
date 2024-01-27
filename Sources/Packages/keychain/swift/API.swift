//
//  API.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation
import XDKX

private protocol StorageAPI {
	func version() -> String
	func read(insecurly key: String) -> Result<Data?, Error>
	func write(insecurly key: String, overwriting: Bool, as value: Data) -> Result<Void, Error>
}

public protocol KeychainAPI {
	func obtainAuthentication(reason: String) async -> Result<Bool, Error>
	func authenticationAvailable() -> Result<Bool, Error>
}

public extension KeychainAPI {
	func read<T>(objectType _: T.Type, id _: String) -> Result<T?, Error> where T: NSObject, T: NSSecureCoding {
		var err: Error? = nil

		let storageKey = "\(T.description())_\(version())"

		guard let data = self.read(insecurly: storageKey).to(&err) else {
			return .failure(x.error("failed to read object", root: err).info("storageKey", storageKey))
		}

		guard let data else { return .success(nil) }

		return Result.X {
			try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
		}
	}

	func write<T>(object: T, overwriting: Bool, id _: String) -> Result<Void, Error> where T: NSObject, T: NSSecureCoding {
		var err: Error? = nil

		let storageKey = "\(T.description())_\(version())"

		guard let resp = Result.X { try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) }.to(&err) else {
			return .failure(x.error("failed to archive object", root: err).info("storageKey", storageKey))
		}

		guard self.write(insecurly: storageKey, overwriting: overwriting, as: resp) == nil else {
			return .failure(x.error("failed to write object", root: err).info("storageKey", storageKey))
		}

		return .success(())
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
