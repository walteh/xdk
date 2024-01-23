//  AppSession.swift
//
//  Created by walter on 3/3/23.
//

import Foundation

import XDKKeychain
import XDKX
import XDKXID

public protocol AppSessionAPI {
	func ID() -> XDKXID.XID
}

public extension AppSessionAPI {
	static func loadFrom(keychain: any XDKKeychain.KeychainAPI) throws -> AppSessionAPI {
		return try KeychainAppSession(keychainAPI: keychain)
	}
}

class AppSessionID: NSObject, NSSecureCoding {
	static var supportsSecureCoding = true

	let id: XDKXID.XID

	init(id: XDKXID.XID) {
		self.id = id
	}

	public func encode(with coder: NSCoder) {
		coder.encode(id.string(), forKey: "id")
	}

	public required init?(coder: NSCoder) {
		let dat = coder.decodeObject(of: NSString.self, forKey: "id")! as String
		id = try! XID.rebuild(string: dat)
	}
}
