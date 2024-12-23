//
//  AppSession.swift
//
//
//  Created by walter on 1/28/24.
//

import Foundation
import Logging
import Err
import LogEvent

public protocol AppSessionAPI: Sendable {
	func ID() -> XID
}

public final class NoopAppSession: AppSessionAPI {
	let base = XID.build()

	public func ID() -> XID {
		return self.base
	}

	public init() {}
}

public struct AppSessionID: Codable, Sendable {
	let id: XID

	init(id: XID) {
		self.id = id
	}

	public init?(coder: NSCoder) {
		let dat = coder.decodeObject(of: NSString.self, forKey: "id")! as String
		self.id = try! XID.rebuild(string: dat).get()
	}

	public var description: String {
		return self.id.string()
	}
}

public final class StoredAppSession: NSObject, Sendable {
	public let appSessionID: AppSessionID

	public let storageAPI: any StorageAPI

	@err public init(storageAPI: any StorageAPI) throws {


		self.storageAPI = storageAPI

		let idres = XDK.Read(using: storageAPI, AppSessionID.self)
		if idres.error != nil {
			throw x.error("failed to read app session id", root: idres.error)
		}

		let id = idres.value!

		if id != nil {
			log(.info).info("sessionID", id).send("idk")
			self.appSessionID = id!
			super.init()
			return
		}

		let tmpid = AppSessionID(id: XID.build())
		guard let _ = XDK.Write(using: storageAPI, tmpid).get() else {
			throw x.error("failed to write app session id", root: err)
		}
		self.appSessionID = tmpid


		super.init()
	}
}

extension StoredAppSession: AppSessionAPI {
	public func ID() -> XID {
		return self.appSessionID.id
	}
}
