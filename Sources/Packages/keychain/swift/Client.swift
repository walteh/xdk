//
//  Client.swift
//  nugg.xyz
//
//  Created by walter on 02/28/2023.
//  Copyright © 2023 nugg.xyz LLC. All rights reserved.
//

import Foundation
import LocalAuthentication
import os
import XDKX

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
		var authenticationContext = LAContext()

		let group: String

		public init(group: String) {
			self.group = group
		}
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

func convertToBytes<T>(struct: T) -> [UInt8] {
	var myStruct = `struct`
	return withUnsafeBytes(of: &myStruct) { Array($0) }
}

extension keychain.Client: keychain.API {
	/// Keychain errors we might encounter.
	public func authenticationAvailable() -> Bool {
		return authenticationContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: nil)
	}

	public func withAuthentication() async -> Result<Bool, Error> {
		guard authenticationAvailable() else {
			return .failure(x.error(keychain.Error.auth_failed))
		}

		return await Result.X { try await self.authenticationContext.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: "Wanna Touch my ID?") }
	}

	public func write<T: NSSecureCoding & NSObject>(object: T, overwriting: Bool, id: String) -> Error? {
		let _data = Result.X { try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) }
		guard let data = _data.value else { return _data.error! }

		return write(insecurly: String(describing: T.self) + "_" + id, overwriting: overwriting, as: Data(data))
	}

	public func read<T: NSSecureCoding & NSObject>(objectType _: T.Type, id: String) -> Result<T?, Error> {
		let _data = read(insecurly: String(describing: T.self) + "_" + id)
		guard let data = _data.value else { return .failure(_data.error!) }

		if data == nil {
			return .success(nil)
		}

		let _from = Result.X { try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data!) }
		guard let from = _from.value else { return .failure(_from.error!) }

		return .success(from)
	}

	/// Stores credentials for the given server.
	public func write(insecurly key: String, overwriting: Bool = false, as value: Data) -> Error? {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
		query[kSecAttrAccessGroup as String] = group
		query[kSecValueData as String] = NSData(data: value)
		query[kSecUseDataProtectionKeychain as String] = true
		query[kSecAttrAccount as String] = key
		query[kSecAttrIsInvisible as String] = true
		query[kSecUseAuthenticationContext as String] = authenticationContext

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
				return x.error(keychain.Error.errSecParam)
			}

			return x.error(status)
		}

		return nil
	}

	/// Reads the stored credentials for the given server.
	public func read(insecurly key: String) -> Result<Data?, Error> {
		var query: [String: Any] = [:]
		query[kSecClass as String] = kSecClassGenericPassword
		query[kSecAttrSynchronizable as String] = true
		query[kSecAttrAccessGroup as String] = group
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = true
		query[kSecUseAuthenticationContext as String] = authenticationContext
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
			return .failure(x.error(status))
		}
	}
}
