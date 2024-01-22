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
	public func read(insecurly _: keychain.Key) -> Data? {
		return nil
	}

	public func write(insecurly _: keychain.Key, overwriting _: Bool, as _: Data) throws {}

	public func withAuthentication() async throws -> Bool {
		return false
	}

	public func authenticationAvailable() -> Bool {
		return false
	}
}
