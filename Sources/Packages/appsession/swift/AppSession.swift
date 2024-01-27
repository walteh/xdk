//  AppSession.swift
//
//  Created by walter on 3/3/23.
//

import Foundation

import XDK
import XDKKeychain
import XDKXID

public protocol AppSessionAPI {
	func ID() -> XDKXID.XID
}

public class NoopAppSession: AppSessionAPI {
	let base = XID.build()

	public func ID() -> XDKXID.XID {
		return self.base
	}

	public init() {}
}

public class AppSessionID: NSObject, NSSecureCoding {
	public static var supportsSecureCoding = true

	let id: XDKXID.XID

	init(id: XDKXID.XID) {
		self.id = id
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.id.string(), forKey: "id")
	}

	public required init?(coder: NSCoder) {
		let dat = coder.decodeObject(of: NSString.self, forKey: "id")! as String
		self.id = try! XID.rebuild(string: dat)
	}
}
