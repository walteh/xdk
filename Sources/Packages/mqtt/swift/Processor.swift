//
//  Processor.swift
//
//
//  Created by walter on 3/10/23.
//

import Foundation

public protocol Processor {
	var topic: String { get }
	func on(message: MQTT5Message)
}
