//
//  AppSession.swift
//
//
//  Created by walter on 1/28/24.
//

import Foundation
import Logging

public protocol AppSessionAPI {
	func ID() -> XID
}

public class NoopAppSession: AppSessionAPI {
	let base = XID.build()

	public func ID() -> XID {
		return self.base
	}

	public init() {}
}

public class AppSessionID: NSObject, NSSecureCoding {
	public static var supportsSecureCoding = true

	let id: XID

	init(id: XID) {
		self.id = id
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.id.string(), forKey: "id")
	}

	public required init?(coder: NSCoder) {
		let dat = coder.decodeObject(of: NSString.self, forKey: "id")! as String
		self.id = try! XID.rebuild(string: dat).get()
	}
}

public class StoredAppSession: NSObject {
	public let appSessionID: AppSessionID

	public let storageAPI: any StorageAPI

	public init(storageAPI: any StorageAPI) throws {
		var err: Error? = nil

		self.storageAPI = storageAPI

		guard var id = XDK.Read(using: storageAPI, AppSessionID.self).to(&err) else {
			throw x.error("failed to read app session id", root: err)
		}

		if id == nil {
			let tmpid = AppSessionID(id: XID.build())
			guard let _ = XDK.Write(using: storageAPI, tmpid).to(&err) else {
				throw x.error("failed to write app session id", root: err)
			}
			id = tmpid
		}

		Log(.info).info("sessionID", id!.description).send("idk")

		self.appSessionID = id!

		super.init()
	}
}

extension StoredAppSession: AppSessionAPI {
	public func ID() -> XID {
		return self.appSessionID.id
	}
}
