//
//  File.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation

public protocol KeychainAPIProtocol: NSObject, ObservableObject {
	func read(insecurly key: keychain.Key) -> Data?
	func write(insecurly key: keychain.Key, overwriting: Bool, as value: Data) throws
	func withAuthentication() async throws -> Bool
	func authenticationAvailable() -> Bool
}

public enum keychain {
	public typealias API = KeychainAPIProtocol

	public struct Key: RawRepresentable {
		public var rawValue: String
		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		static let PasskeySessionID = keychain.Key(rawValue: "PasskeySessionID")
		static let AppAttestKey = keychain.Key(rawValue: "AppAttestKey")
		static let PasskeyCredentialID = keychain.Key(rawValue: "PasskeyCredentialID")
		static let WebauthnSessionID = keychain.Key(rawValue: "WebauthnSessionID")
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
