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

	override public var description: String {
		return self.id.string()
	}
}

public class StoredAppSession: NSObject {
	public let appSessionID: AppSessionID

	public let storageAPI: any StorageAPI

	public init(storageAPI: any StorageAPI) throws {
		var err: Error? = nil

		self.storageAPI = storageAPI

		var idres = XDK.Read(using: storageAPI, AppSessionID.self)
		if idres.error != nil {
			throw x.error("failed to read app session id", root: idres.error)
		}
		
		var id = idres.value!

		if id == nil {
			let tmpid = AppSessionID(id: XID.build())
			guard let _ = XDK.Write(using: storageAPI, tmpid).to(&err) else {
				throw x.error("failed to write app session id", root: err)
			}
			self.appSessionID = tmpid
		} else {
			Log(.info).info("sessionID", id).send("idk")
			self.appSessionID = id!
		}


		super.init()
	}
}

extension StoredAppSession: AppSessionAPI {
	public func ID() -> XID {
		return self.appSessionID.id
	}
}
