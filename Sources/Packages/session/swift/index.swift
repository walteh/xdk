
import Foundation

import keychain_swift
import x_swift
import xid_swift

public enum session {
	public typealias API = SessionAPI

	public static func loadFrom(keychain: any keychain.API) -> SessionAPI {
		return KeychainSession(keychainAPI: keychain)
	}
}

public protocol SessionAPI {
	func ID() -> xid.ID
}

extension keychain.Key {
	static let SessionID = keychain.Key(rawValue: "SessionID")
}

class KeychainSession: NSObject {
	public let sessionID: xid.ID

	public let keychainAPI: any keychain.API

	init(keychainAPI: any keychain.API) {
		self.keychainAPI = keychainAPI
		let res = self.keychainAPI.read(insecurly: .SessionID)

		var id: xid.ID? = nil

		if let res {
			do {
				id = try xid.ID(raw: res)
			} catch {
				x.error(error).log()
			}
		}

		if id == nil {
			let tmpid = xid.New()
			do {
				try self.keychainAPI.write(insecurly: .SessionID, overwriting: true, as: tmpid.data)
				id = tmpid
			} catch {
				x.error(error)
			}
		}

		if id == nil {
			fatalError("could not save session id to keychain")
		}

		x.log(.info).add("sessionID", id).msg("idk")

		self.sessionID = id!

		super.init()
	}
}

extension KeychainSession: SessionAPI {
	func ID() -> xid.ID {
		return self.sessionID
	}
}
