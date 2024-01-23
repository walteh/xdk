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
import XDKX

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

class LocalAuthenticationClient: NSObject, ObservableObject {
	var authenticationContext = LAContext()

	let group: String

	public init(group: String) {
		self.group = group
	}
}

func convertFromBytes<T>(bytes: [UInt8], type _: T.Type) -> T {
	let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
	_ = pointer.withMemoryRebound(to: UInt8.self, capacity: bytes.count) {
		ptr in memcpy(ptr, bytes, bytes.count)
	}
	let structValue = pointer.pointee
	pointer.deallocate()
	return structValue
}

func convertToBytes(struct: some Any) -> [UInt8] {
	var myStruct = `struct`
	return withUnsafeBytes(of: &myStruct) { Array($0) }
}

extension LocalAuthenticationClient: KeychainAPI {
	/// Keychain errors we might encounter.
	public func authenticationAvailable() -> Bool {
		return self.authenticationContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: nil)
	}

	public func withAuthentication() async -> Result<Bool, Error> {
		guard self.authenticationAvailable() else {
			return .failure(x.error("unable to authenticate", root: KeychainError.auth_failed))
		}

		return await Result.X { try await self.authenticationContext.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: "Wanna Touch my ID?") }
	}

	/// Stores credentials for the given server.
	public func write(insecurly key: String, overwriting: Bool = false, as value: Data) -> Error? {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
		query[kSecAttrAccessGroup as String] = self.group
		query[kSecValueData as String] = NSData(data: value)
		query[kSecUseDataProtectionKeychain as String] = true
		query[kSecAttrAccount as String] = key
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
					return nil
				}
			}

			if status == errSecParam {
				return x.error("unable to write", root: KeychainError.errSecParam)
			}

			return x.error(status: status)
		}

		return nil
	}

	/// Reads the stored credentials for the given server.
	public func read(insecurly key: String) -> Result<Data?, Error> {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessGroup as String] = self.group
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = true
		query[kSecUseAuthenticationContext as String] = self.authenticationContext
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
}
