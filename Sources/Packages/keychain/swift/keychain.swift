//
//  keychain.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation

public protocol KeychainAPIProtocol {
	func read(insecurly key: String) -> Result<Data?, Error>
	func write(insecurly key: String, overwriting: Bool, as value: Data) -> Error?
	func read<T: NSSecureCoding & NSObject>(objectType: T.Type, id: String) -> Result<T?, Error>
	func write<T: NSSecureCoding & NSObject>(object: T, overwriting: Bool, id: String) -> Error?
	func withAuthentication() async -> Result<Bool, Error>
	func authenticationAvailable() -> Bool
}

public enum keychain {
	public typealias API = KeychainAPIProtocol

	public struct Key: RawRepresentable {
		public var rawValue: String
		public init(rawValue: String) {
			self.rawValue = rawValue
		}
	}

	public enum Error: Swift.Error {
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
}
