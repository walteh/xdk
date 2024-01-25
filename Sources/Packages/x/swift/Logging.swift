//
//  Logging.swift
//  app
//
//  Created by walter on 9/29/22.
//

import Foundation
import Logging

public let xlogger = Logging.Logger(label: "XDK")

public extension x {
	static func log(_ level: Logging.Logger.Level = .info, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> LogEvent {
		return LogEvent(level, __file: __file, __function: __function, __line: __line)
	}
}

public class LogEvent {
	public let level: Logging.Logger.Level
	public let caller: String
	public var error: Swift.Error?
	public let __file: String
	public let __function: String
	public let __line: UInt

	public init(_ level: Logging.Logger.Level, __file: String = #fileID, __function: String = #function, __line: UInt = #line) {
		self.level = level
		self.metadata["function"] = .string(__function)
		self.caller = "\(__file.split(separator: "/").last!):\(__line)"
		self.__file = __file
		self.__line = UInt(__line)
		self.__function = __function
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

	public func err(_ err: Swift.Error?) -> Self {
		self.error = err
		return self
	}

	public func add(_ key: String, string: String) -> Self {
		return self.info(key, string)
	}

	public func add(_ key: String, any: Any) -> Self {
		return self.info(key, any: any)
	}

	public func add(_ key: String, _ s: some CustomDebugStringConvertible) -> Self {
		return self.info(key, s)
	}

	public func info(_ key: String, string: String) -> Self {
		self[metadataKey: key] = .string(string)
		return self
	}

	public func info(_ key: String, any: Any) -> Self {
		self[metadataKey: key] = .string(String(reflecting: any))
		return self
	}

	public func info(_ key: String, _ s: some CustomDebugStringConvertible) -> Self {
		self[metadataKey: key] = .string(s.debugDescription)
		return self
	}

	@inlinable
	public func send(_ str: some CustomDebugStringConvertible) {
		if self.error == nil {
			xlogger.log(level: self.level, .init(stringLiteral: str.debugDescription), metadata: self.metadata, source: self.caller, file: self.__file, function: self.__function, line: self.__line)
		} else {
			var errStr = ""
			if let err = self.error as? XError {
				errStr = err.dump()
			} else if let err = self.error as? NSError {
				errStr = "\(err)"
			}
			self[metadataKey: "note"] = .string(str.debugDescription)
			xlogger.log(level: self.level, .init(stringLiteral: errStr), metadata: self.metadata, source: self.caller, file: self.__file, function: self.__function, line: self.__line)
		}
	}
}
