//
//  Data+UUID.swift
//  nugg.xyz
//
//  Created by walter on 11/23/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

public extension UUID {
	func asUInt8Array() -> [UInt8] {
		let (u1, u2, u3, u4, u5, u6, u7, u8, u9, u10, u11, u12, u13, u14, u15, u16) = self.uuid
		return [u1, u2, u3, u4, u5, u6, u7, u8, u9, u10, u11, u12, u13, u14, u15, u16]
	}

	func asData() -> Data {
		return Data(self.asUInt8Array())
	}
}
