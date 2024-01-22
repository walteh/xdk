//
//  File.swift
//
//
//  Created by walter on 3/5/23.
//

import Foundation

public extension mtx {
	class Noop: NSObject {
		override public init() {}
	}
}

extension mtx.Noop: mtx.API {
	public func addToQueue() {}

	public func getStoreFront() {}

	public func getProducts() {}

	public func Purchase(transaction _: String) async throws -> Bool {
		return false
	}
}
