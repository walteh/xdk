//
//  Session.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import ecdsa_swift
import keychain_swift
import xid_swift

// public extension webauthn {
//	class Session: NSObject {
//		public let sessionID: Data
//
//		public let keychainApi: any keychain.API
//
//		init(keychainApi: any keychain.Api) {
//			self.keychainAPI = keychainAPI
//			let res = self.keychainApi.read(insecurly: .WebauthnSessionID)
//
//			if res != nil, !res!.isEmpty {
//				self.sessionID = res!
//			} else {
//				let dat = xid.New()
//				try? self.keychainApi.write(insecurly: .WebauthnSessionID,overwriting: true, as: dat.data)
//				self.sessionID = dat.data
//			}
//
//			super.init()
//		}
//	}
// }
