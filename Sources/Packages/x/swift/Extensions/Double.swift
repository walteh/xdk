//
//  Double.swift
//  nugg.xyz
//
//  Created by walter on 11/6/22.
//

import Foundation

public extension Double {
	func toEth() -> Double {
		self / pow(10, 18)
	}
}
