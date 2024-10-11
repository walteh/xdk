//
//  LocalAuthentication.swift
//  nugg.xyz
//
//  Created by walter on 02/28/2023.
//  Copyright © 2023 nugg.xyz LLC. All rights reserved.
//

import Foundation
import LocalAuthentication
import os
import XDK
@_spi(ExperimentalLanguageFeature) public import Err

extension LAContext {
	func evaluatePolicy(_ policy: LAPolicy, localizedReason reason: String) async throws -> Bool {
		return try await withCheckedThrowingContinuation { cont in
			self.evaluatePolicy(policy, localizedReason: reason) { result, error in
				if let error { return cont.resume(throwing: error) }
				cont.resume(returning: result)
			}
		}
	}
}

public final class LocalAuthenticationClient: NSObject, ObservableObject, Sendable {
	// let authenticationContext =

	let group: String
	let _version: String

	public init(group: String, version: String) {
		self.group = group
		self._version = version
	}
}

extension LocalAuthenticationClient: XDK.StorageAPI {
	public func version() -> String {
		return self._version
	}

	/// Stores credentials for the given server.
	public func write(unsafe key: String, overwriting: Bool, as value: Data) -> Result<Void, Error> {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
		query[kSecAttrAccessGroup as String] = self.group
		query[kSecValueData as String] = NSData(data: value)
		query[kSecUseDataProtectionKeychain as String] = true
		query[kSecAttrAccount as String] = key
		query[kSecAttrIsInvisible as String] = true
		query[kSecUseAuthenticationContext as String] = LAContext()

		//		query[kSecAttrIsSensitive as String] = true
		var status = SecItemAdd(query as CFDictionary, nil)

		guard status == errSecSuccess else {
			if status == errSecDuplicateItem, overwriting {
				status = SecItemDelete(query as CFDictionary)
				if status == errSecSuccess {
					status = SecItemAdd(query as CFDictionary, nil)
					if status == errSecSuccess {
						return .success(())
					} else {
						return .failure(x.error("unable to overwrite", root: KeychainError.errSecParam))
					}
				} else {
					return .failure(x.error("unable to delete"))
				}
			}

			if status == errSecParam {
				return .failure(x.error("unable to write", root: KeychainError.errSecParam))
			}

			return .failure(x.error(status: status))
		}

		return .success(())
	}

	/// Reads the stored credentials for the given server.
	public func read(unsafe key: String) -> Result<Data?, Error> {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessGroup as String] = self.group
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = true
		query[kSecUseAuthenticationContext as String] = LAContext()
		query[kSecAttrAccount as String] = key

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)

		switch status {
		case errSecSuccess:
			guard let passwordData = item as? Data else { return .success(nil) }
			if passwordData.isEmpty { return .success(nil) }
			return .success(passwordData)
		case errSecItemNotFound:
			return .success(nil)
		default:
			return .failure(x.error(status: status))
		}
	}

	/// Deletes the stored credentials for the given server.
	public func delete(unsafe key: String) -> Result<Void, Error> {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessGroup as String] = self.group
		query[kSecAttrAccount as String] = key
		query[kSecUseAuthenticationContext as String] = LAContext()

		let status = SecItemDelete(query as CFDictionary)

		switch status {
		case errSecSuccess:
			return .success(())
		case errSecItemNotFound:
			return .success(())
		default:
			return .failure(x.error(status: status))
		}
	}
}

extension LocalAuthenticationClient: XDK.AuthenticationAPI {
	/// Keychain errors we might encounter.
	public func authenticationAvailable() -> Result<Bool, Error> {
		var err: NSError?
		let ok = LAContext().canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: &err)
		if err != nil {
			return .failure(x.error("unable to check authentication availability", root: err))
		}

		return .success(ok)
	}

	@err
	public func obtainAuthentication(reason: String) async -> Result<Bool, Error> {

		guard let _ = self.authenticationAvailable().err() else {
			return .failure(x.error("local auth not available", root: err, alias: KeychainError.auth_failed))
		}

		guard let res = try await LAContext().evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: reason) else {
			return .failure(x.error("unable to authenticate", root: err, alias: KeychainError.auth_failed))
		}

		return .success(res)
	}
}
