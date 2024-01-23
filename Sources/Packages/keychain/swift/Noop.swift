//
//  File.swift
//
//
//  Created by walter on 3/5/23.
//

import Foundation
import XDKX

class NoopClient: NSObject {
	var store = [String: Data]()

	override public init() {}
}

extension NoopClient: KeychainAPI {
	public func authenticationAvailable() -> Bool {
		return true
	}
	
	
	public func read(insecurly key: String) -> Result<Data?, Error> {
		return .success(self.store[key])
	}
	
	public func write(insecurly key: String, overwriting: Bool, as value: Data) -> Error? {
		self.store[key] = value
		return nil
	}
	

	
	public func withAuthentication() async -> Result<Bool, Error> {
		return .success(true)
	}
}
