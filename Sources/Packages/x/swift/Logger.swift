//
//  Logger.swift
//  app
//
//  Created by walter on 9/29/22.
//

import Foundation
import Logging

let xlogger = Logging.Logger(label: "XDK")

public extension x {
	static func log(_ level: Logging.Logger.Level = .info, __file: String = #fileID, __function: String = #function, __line: Int = #line) -> LogEvent {
		return LogEvent(level, __file: __file, __function: __function, __line: __line)
	}
}

public class LogEvent {
	public let level: Logging.Logger.Level
	public let caller: String
	public var error: Swift.Error?

	public init(_ level: Logging.Logger.Level, __file: String = #fileID, __function: String = #function, __line: Int = #line) {
		self.level = level
		self.metadata["function"] = .string(__function)
		self.caller = "\(__file.split(separator: "/").last!):\(__line)"
	}

	public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
		get {
			return self.metadata[key]
		}
		set(newValue) {
			self.metadata[key] = newValue
		}
	}

	public var metadata: Logging.Logger.Metadata = [:]

	public func add(_ key: String, string: String) -> LogEvent {
		self[metadataKey: key] = .string(string)
		return self
	}

	public func err(_ err: Swift.Error?) -> LogEvent {
		self.error = err
		return self
	}

	public func add(_ key: String, any: Any) -> LogEvent {
		self[metadataKey: key] = .string(String(reflecting: any))
		return self
	}

	public func add(_ key: String, _ s: some CustomDebugStringConvertible) -> LogEvent {
		self[metadataKey: key] = .string(s.debugDescription)
		return self
	}

	public func send(_ str: some CustomDebugStringConvertible) {
//		self.metadata["line"] = .stringConvertible(line)
//		self.metadata["function"] = .string(function)
//		self.metadata["file"] = .string(file)
		xlogger.log(level: self.level, .init(unicodeScalarLiteral: .init(describing: str)), metadata: self.metadata, source: self.caller)

		if let err = self.error as? x.Error {
			xlogger.error(.init(stringLiteral: err.dump()))
		} else if let err = self.error {
			xlogger.error(.init(stringLiteral: err.localizedDescription))
		}
	}
}

public extension Logging.Logger.Metadata {
	func getCaller() -> (String, String, Int) {
		return (self["function"]?.description ?? "", self["file"]?.description ?? "", (try? Int(self["line"]?.description ?? "", format: .number)) ?? 0)
	}
}

// class ConsoleHandler: Logging.LogHandler {
//	public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
//		get {
//			return self.metadata[key]
//		}
//		set(newValue) {
//			self.metadata[key] = newValue
//		}
//	}
//
//	public var metadata: Logging.Logger.Metadata = [:]
//
//	public var logLevel: Logging.Logger.Level = .info
//
//	public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
//
//	}
// }

// public class XLogger {
//
//	static let startTime = Date()
//
//	static let logger = Logging.Logger(label: "main")
//
//	static let logLevel: Logging.Logger.Level = .info
//
////	private static func timeSinceStart() -> Double {
////		let start = self.startTime
////		return Date().timeIntervalSince(start)
////	}
////
////	static func timeFormatted() -> String {
////		let numberFormatter = NumberFormatter()
////		numberFormatter.minimumIntegerDigits = 10
////		numberFormatter.allowsFloats = true
////		numberFormatter.maximumFractionDigits = 5
////		numberFormatter.minimumFractionDigits = 5
////		return numberFormatter.string(from: NSNumber(floatLiteral: self.timeSinceStart()))!
////	}
//
////	public static func log<A: Any>(_ level: LogLevel = .info, _ obj: A?, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
////		if obj == nil {
////			self.log(level: level, string: "nil", __file: __file, __line: __line, __function: __function)
////		} else if let err = obj as? Error {
////			self.error(err, __file: __file, __line: __line, __function: __function)
////		} else if let str = obj as? String {
////			self.log(level: level, string: str, __file: __file, __line: __line, __function: __function)
////		} else if let str = obj as? CustomStringConvertible {
////			self.log(level: level, string: str.description, __file: __file, __line: __line, __function: __function)
////		} else if let str = obj as? CustomDebugStringConvertible {
////			self.log(level: level, string: str.debugDescription, __file: __file, __line: __line, __function: __function)
////		} else {
////			self.log(level: level, string: "\(obj.debugDescription)", __file: __file, __line: __line, __function: __function)
////		}
////	}
//
//	private static func log(level: Logger.Level, string s: String, __file: String = #fileID, __line: Int = #line, __function _: String = #function) {
//		var logger = logger
//		logger[metadataKey: "thread"] = .string(Thread.current.queueName)
//		logger[metadataKey: "caller"] = .string("\(__file.split(separator: "/").last!):\(__line)")
//
//
////		if level.rawValue > self.logLevel.rawValue { return }
//		let location = "\(__file.split(separator: "/").last!):\(__line)"
//		self.logger.log(level: level, .init(stringLiteral: s))
//	}
//
//	static func crumb(_ s: String, attributes _: [AnyHashable: NSObject] = [:], __file: String = #fileID, __line: Int = #line, __function: String = #function) {
////		if LogLevel.trace.rawValue < self.logLevel.rawValue { return }
//		self.log(level: .trace, string: "[CRUMB:\(s)]", __file: __file, __line: __line, __function: __function)
//	}
//
//	static func event(_ eventType: String, attributes _: [AnyHashable: NSObject] = [:], __file: String = #fileID, __line: Int = #line, __function: String = #function) {
//		self.log(level: .trace, string: "[EVENT:\(eventType)]", __file: __file, __line: __line, __function: __function)
//	}
//
//	static func appendFileToAttributes(_ attrs: [AnyHashable: NSObject], file: String, line: Int, function: String) -> [AnyHashable: NSObject] {
//		var working = attrs
//		working["location"] = NSString(string: "\(file.split(separator: "/").last!):\(line)")
//		working["function"] = NSString(string: function)
//		return working
//	}
//
//	public static func error(_ s: Error, attributes _: [AnyHashable: NSObject] = [:], __file: String = #fileID, __line: Int = #line, __function _: String = #function) {
//		let location = "\(__file.split(separator: "/").last!):\(__line)"
////		self.logger.error(
//	}
//
//	public static func error(_ s: NSError, attributes _: [AnyHashable: NSObject] = [:], __file: String = #fileID, __line: Int = #line, __function _: String = #function) {
//		let location = "\(__file.split(separator: "/").last!):\(__line)"
////		self.logger.log(level: .error, "\(self.timeFormatted()) | \(LogLevel.error.toString()) | \(location) | * \(Thread.current.queueName) | \(s.debugDescription)")
//	}
// }
//
//
//

//
////public enum LogLevel: Int {
////	case error
////	case warn
////	case info
////	case time
////	case debug
////	case trace
////
////	func toString() -> String {
////		switch self {
////		case .error: return "ERR ❌"
////		case .warn: return "WAR ⚠️"
////		case .info: return "INF 🟢"
////		case .time: return "TIM ⏱️"
////		case .debug: return "DBG 🦞"
////		case .trace: return "TRC 🔀"
////		}
////	}
////
//////	func toOS() -> Logging.Logger.Level {
//////		switch self {
//////		case .error: return .error
//////		case .warn: return .warning
//////		case .info: return .info
//////		case .trace: return .trace
//////		case .debug: return .
//////		case .time: return OSLogType.debug
//////		}
//////	}
////}
