//  KeychainAppSession.swift
//
//  Created by walter on 1/23/24.
//

import Foundation

import XDK
import XDKXID

public class StoredAppSession: NSObject {
	public let appSessionID: AppSessionID

	public let storageAPI: any StorageAPI

	public init(storageAPI: any StorageAPI) throws {
		var err = Error?.none

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

		x.log(.info).add("sessionID", id!.description).send("idk")

		self.appSessionID = id!

		super.init()
	}
}

extension StoredAppSession: AppSessionAPI {
	public func ID() -> XDKXID.XID {
		return self.appSessionID.id
	}
}
