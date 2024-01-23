//
//  File.swift
//
//
//  Created by walter on 3/5/23.
//

import Foundation

public extension keychain {
	class Noop: NSObject {
		override public init() {}
	}
}

extension keychain.Noop: keychain.API {
	public func read(insecurly key: String) -> Result<Data?, Error> {
		return .success(nil)
	}
	
	public func write(insecurly key: String, overwriting: Bool, as value: Data) -> Error? {
		return nil
	}
	
	public func read<T>(objectType: T.Type, id: String) -> Result<T?, Error> where T : NSObject, T : NSSecureCoding {
		return .success(nil)
	}
	
	public func write<T>(object: T, overwriting: Bool, id: String) -> Error? where T : NSObject, T : NSSecureCoding {
		return nil
	}
	
	public func withAuthentication() async -> Result<Bool, Error> {
		return .success(true)
	}
	
	public func withAuthentication() async throws -> Bool {
		return false
	}

	public func authenticationAvailable() -> Bool {
		return false
	}
}
