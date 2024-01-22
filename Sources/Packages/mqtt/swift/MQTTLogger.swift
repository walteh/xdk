//
//  MQTTLogger.swift
//  MQTT
//
//  Created by HJianBo on 2019/5/2.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation
import os

import x_swift

// Convenience functions
func printDebug(_ message: String, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
	x.log(.debug).msg(message, file: __file, function: __function, line: __line)
}

func printInfo(_ message: String, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
	x.log(.info).msg(message, file: __file, function: __function, line: __line)
}

func printWarning(_ message: String, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
	x.log(.warning).msg(message, file: __file, function: __function, line: __line)
}

func printError(_ message: String, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
	x.log(.error).msg(message, file: __file, function: __function, line: __line)
}

// Enum log levels
public enum MQTTLoggerLevel: Int {
	case debug = 0, info, warning, error, off
}

open class MQTTLogger: NSObject {
	// Singleton
	public static var logger = MQTTLogger()
	override public init() { super.init() }

	// min level
	var minLevel: MQTTLoggerLevel = .warning

	// logs
	open func log(level: MQTTLoggerLevel, message: String) {
		guard level.rawValue >= self.minLevel.rawValue else { return }
		print("MQTT(\(level)): \(message)")
	}

	func debug(_ message: String) {
		self.log(level: .debug, message: message)
	}

	func info(_ message: String) {
		self.log(level: .info, message: message)
	}

	func warning(_ message: String) {
		self.log(level: .warning, message: message)
	}

	func error(_ message: String) {
		self.log(level: .error, message: message)
	}
}
