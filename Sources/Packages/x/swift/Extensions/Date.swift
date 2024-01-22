//
//  Date.swift
//  app
//
//  Created by walter on 10/13/22.
//

import Foundation

extension Date {
	var millisecondsSince1970: Int64 {
		Int64((self.timeIntervalSince1970 * 1000.0).rounded())
	}

	init(milliseconds: Int64) {
		self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
	}
}
