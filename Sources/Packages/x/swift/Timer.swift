//
//  Timer.swift
//  nugg.xyz
//
//  Created by walter on 12/3/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

public class Timer {
	let start: Date
	let name: String

	public init(name: String) {
		self.name = name
		self.start = Date()
	}

	public func end() {
		let timeElapsed = DateInterval(start: start, end: Date()).duration
		x.log(.info).add("time_elapsed", string: "\(timeElapsed) s.").send("end timer \(self.name)")
	}
}
