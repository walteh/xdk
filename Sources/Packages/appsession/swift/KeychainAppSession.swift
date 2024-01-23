//  KeychainAppSession.swift
//
//  Created by walter on 1/23/24.
//

import Foundation

import XDKKeychain
import XDKX
import XDKXID

public class KeychainAppSession: NSObject {
	public let appSessionID: AppSessionID

	public let keychainAPI: any KeychainAPI

	init(keychainAPI: any KeychainAPI) throws {
		self.keychainAPI = keychainAPI

		var id = try self.keychainAPI.read(objectType: AppSessionID.self, id: "default").get()

		if id == nil {
			let tmpid = AppSessionID(id: XID.build())
			if let err = self.keychainAPI.write(object: tmpid, overwriting: true, id: "default") {
				throw err
			}
			id = tmpid
		}

		x.log(.info).add("sessionID", id!.description).send("idk")

		self.appSessionID = id!

		super.init()
	}
}

extension KeychainAppSession: AppSessionAPI {
	public func ID() -> XDKXID.XID {
		return self.appSessionID.id
	}
}
