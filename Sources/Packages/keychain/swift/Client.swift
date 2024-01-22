//
//  hex.swift
//  nugg.xyz
//
//  Created by walter on 02/28/2023.
//  Copyright © 2023 nugg.xyz LLC. All rights reserved.
//

import Foundation
import LocalAuthentication
import os

public extension LAContext {
	func evaluatePolicy(_ policy: LAPolicy, localizedReason reason: String) async throws -> Bool {
		return try await withCheckedThrowingContinuation { cont in
			self.evaluatePolicy(policy, localizedReason: reason) { result, error in
				if let error { return cont.resume(throwing: error) }
				cont.resume(returning: result)
			}
		}
	}
}

public extension keychain {
	class Client: NSObject, ObservableObject {
		internal var authenticationContext = LAContext()

		let group: String

		public init(group: String) {
			self.group = group
		}
	}
}

extension keychain.Client: keychain.API {
	/// Keychain errors we might encounter.
	public func authenticationAvailable() -> Bool {
		return self.authenticationContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: nil)
	}

	public func withAuthentication() async throws -> Bool {
		guard self.authenticationAvailable() else {
			throw keychain.Error.auth_failed
		}

		return try await self.authenticationContext.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: "Wanna Touch my ID?")
	}

	/// Stores credentials for the given server.
	public func write(insecurly key: keychain.Key, overwriting: Bool = false, as value: Data) throws {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
		query[kSecAttrAccessGroup as String] = group
		query[kSecValueData as String] = NSData(data: value)
		query[kSecUseDataProtectionKeychain as String] = true
		query[kSecAttrAccount as String] = key.rawValue
		query[kSecAttrIsInvisible as String] = true
		query[kSecUseAuthenticationContext as String] = self.authenticationContext

		print(query.debugDescription)

		//		query[kSecAttrIsSensitive as String] = true
		var status = SecItemAdd(query as CFDictionary, nil)

		guard status == errSecSuccess else {
			if status == errSecDuplicateItem, overwriting {
				SecItemDelete(query as CFDictionary)
				status = SecItemAdd(query as CFDictionary, nil)
				if status == errSecSuccess {
					return
				}
			}

			if status == errSecParam {
				throw keychain.Error.errSecParam
			}

			throw keychain.Error.unhandled(status: status)
		}
	}

	/// Reads the stored credentials for the given server.
	public func read(insecurly key: keychain.Key) -> Data? {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessGroup as String] = group
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = true
		query[kSecUseAuthenticationContext as String] = self.authenticationContext
		query[kSecAttrAccount as String] = key.rawValue

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)

		guard status == errSecSuccess
		else {
			return nil
		}

		guard let passwordData = item as? Data else { return nil }

		if passwordData.isEmpty { return nil }

		return passwordData
	}
}
