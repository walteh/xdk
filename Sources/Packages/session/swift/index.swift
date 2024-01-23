
import Foundation

import XDKKeychain
import XDKX
import XDKXID

public enum session {
	public typealias API = SessionAPI

	public static func loadFrom(keychain: any keychain.API) throws -> SessionAPI {
		return try KeychainSession(keychainAPI: keychain)
	}
}

class SessionID: NSObject, NSSecureCoding {
	static var supportsSecureCoding = true

	let _id: Data
	
	var id: XDKXID.xid.XID {
		return try! xid.XID(raw: _id)
	}

	init(id: XDKXID.xid.XID) {
		self._id = id.bytes
	}

	public func encode(with coder: NSCoder) {
		coder.encode(id, forKey: "id")
	}

	required public init?(coder: NSCoder) {
		self._id = coder.decodeObject(of: NSData.self, forKey: "id")! as Data
	}
}


public protocol SessionAPI {
	func ID() -> xid.XID
}

class KeychainSession: NSObject {
	public let sessionID: SessionID

	public let keychainAPI: any keychain.API

	init(keychainAPI: any keychain.API) throws {
		self.keychainAPI = keychainAPI
		
		var id = try self.keychainAPI.read(objectType: SessionID.self, id: "default").get()
		
		if id == nil {
			let tmpid = SessionID(id: xid.New())
			if let err = self.keychainAPI.write(object: tmpid, overwriting: true, id: "default") {
				throw err
			}
			id = tmpid
		}


		x.log(.info).add("sessionID", id!.description).msg("idk")

		sessionID = id!

		super.init()
	}
}

extension KeychainSession: SessionAPI {
	func ID() -> xid.XID {
		return sessionID.id
	}
}
