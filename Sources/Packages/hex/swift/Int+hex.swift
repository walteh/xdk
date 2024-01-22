//
//  File.swift
//
//
//  Created by walter on 3/4/23.
//

import Foundation

extension Int {
	func addressify() -> String {
		String(format: "0x%040X", self)
	}
}
