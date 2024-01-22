//
//  Data+Sha2.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import CryptoKit
import Foundation

public extension Data {
	func sha2() -> Data {
		Data(SHA256.hash(data: self))
	}
}
