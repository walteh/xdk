//
//  Error.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation
import Logging

public func Err(_ str: String, root: (any Swift.Error)? = nil, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> XError {
	return XError(str, root: root, alias: alias, __file: __file, __function: __function, __line: __line)
}

public extension x {
	@discardableResult
	static func error(_ str: String, root: (any Swift.Error)? = nil, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> XError {
		return XError(str, root: root, alias: alias, __file: __file, __function: __function, __line: __line)
	}

	@discardableResult
	static func error(status: OSStatus, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> XError {
		return XError("OSStatus[\(status)]", alias: alias, __file: __file, __function: __function, __line: __line)
	}
}

public final class XError: NSError, @unchecked Sendable {
	override public var underlyingErrors: [Error] {
		if let r = selfroot {
			return [r]
		}
		return []
	}

	override public var userInfo: [String: Any] {
		var info = super.userInfo
		for i in self.metadata {
			if case let .stringConvertible(v) = i.value {
				info[i.key] = v
			} else {
				info[i.key] = "\(i.value)"
			}
		}
		return info
	}

	public let message: String
	let selfroot: Error?
	public let alias: Error?

	public var metadata: Logging.Logger.Metadata = [:]

	public let caller: Caller

	public required convenience init(rawValue: String) {
		self.init(rawValue)
	}

	public init(_ message: String, root: (any Swift.Error)? = nil, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) {
		if let r = root {
			self.selfroot = r
		} else {
			self.selfroot = nil
		}

		if let r = alias {
			self.alias = r
		} else {
			self.alias = nil
		}

		self.message = message
		self.caller = Caller(file: __file, function: __function, line: __line)
		self.metadata["function"] = .string(__function)
		super.init(domain: "XError", code: -6, userInfo: [:])
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public func info(_ key: String, _ value: Any) -> Self {
		return self.info([key: value])
	}

	public func info(description: String) -> Self {
		return self.info(NSLocalizedDescriptionKey, description)
	}

	public func info(failure: String) -> Self {
		return self.info(NSLocalizedFailureErrorKey, failure)
	}

	public func info(failureReason: String) -> Self {
		return self.info(NSLocalizedFailureReasonErrorKey, failureReason)
	}

	public func info(recoverySuggestion: String) -> Self {
		return self.info(NSLocalizedRecoverySuggestionErrorKey, recoverySuggestion)
	}

	public func event(_ manip: (LogEvent) -> LogEvent) -> Self {
		var event = LogEvent(.error)
		event = manip(event)
		return self.info(event.metadata)
	}

	public func info(_ data: [String: Any]) -> Self {
		for i in data {
			if let r = i.value as? (String) {
				self.metadata[i.key] = .stringConvertible(r)
			} else {
				self.metadata[i.key] = .stringConvertible("\(i.value)")
			}
		}
		return self
	}
}

public extension Error {
	// ==
	static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.localizedDescription == rhs.localizedDescription
	}

	func contains(_ g: some Swift.Error) -> Bool {
		let r = self as RootListableError
		return r.deepest(matching: g) != nil

	}

	func contains<G: Swift.Error>(_: G.Type) -> Bool {
		 let r = self as RootListableError
			return r.deepest(ofType: G.self) != nil
	}
}

// func check<G: Swift.Error>(error: some Error, contains _: G) -> Bool {
// 	let error = error as NSError
// 	return (error.deepest(ofType: G.self)) == nil
// }

public protocol RootListableError: Swift.Error {
	var underlyingErrors: [Error] { get }
}

public protocol AliasableError: Swift.Error {
	var alias: Swift.Error? { get }
}

extension NSError: RootListableError {}
extension XError: AliasableError {}

public extension RootListableError {
	func root() -> Error? {
		if self.underlyingErrors.count == 1 {
			return self.underlyingErrors[0]
		}
		return nil
	}

	func rootList() -> [Swift.Error] {
		// loop through the roots, and append each to a string backwards
		var strs = [Swift.Error]()
		strs += [self]
		var _root: NSError? = self.root() as NSError? ?? nil
		while _root != nil {
			strs += [_root!]
			_root = _root!.root() as NSError? ?? nil
		}
		strs.reverse()
		return strs
	}

	func deepest<T: Swift.Error>(ofType _: T.Type) -> Swift.Error? {
		let list = self.rootList()

		for i in list {
			if let r = i as? T {
				return r
			}
			if let r = i as? AliasableError {
				if r.alias is T {
					return i
				}
			}
			let r = i as NSError
			if r.domain == i._domain, r.code == i._code {
				return i
			}

		}
		return nil
	}

	func deepest(matching: some Swift.Error) -> Swift.Error? {
		let list = self.rootList()

		for i in list {
			// if let r = i as? T {
			if i == matching {
				return i
			}
			// }
			if let r = i as? AliasableError {
				if r.alias != nil, r.alias! == matching {
					return i
				}
			}
			let r = i as NSError
			if r.domain == i._domain, r.code == i._code {
				return i
			}
		}
		return nil
	}
}

public extension NSError {
	var localizedDescription: String {
		return (self as RootListableError).localizedDescription
	}

	override var debugDescription: String {
		let strs = self.rootList().map {
			if let errd = $0 as? XError {
				return errd.description
			} else {
				return ($0 as NSError).description
			}
		}
		var result = ""
		for i in 0 ..< strs.count {
			if i == strs.count - 1 {
				result += strs[i]
			} else if i == strs.count - 2 {
				result += strs[i] + " 👉 ❌ "
			} else {
				result += strs[i] + " 👉 "
			}
		}

		return result
	}

	// override var description: String {
	// 	return (self as RootListableError).localizedDescription
	// }

	override var description: String {
		if let r = self as? XError {
			return "XError[ message=\"\(r.message)\" caller=\"\(r.caller.format())\" ]"
		}
		return "NSError[ domain=\"\(self.domain)\" code=\"\(self.code)\" ]"
	}
}

// struct DumpedError: CustomStringConvertible {

// 	let error: Swift.Error

// 	var description: String {
// 		if let r = self.error as? RootListableError {
// 			return r.dump()
// 		} else if let r = self.error as? NSError {
// 			return "\(r)"
// 		}
// 		return "\(self.error)"
// 	}

// 	func dump(err: Error) -> String {
// 		var stream = ""

// 		let list = (err as NSError).rootList()

// 		stream += "\n\n"

// 		// Start with the initial log message
// 		// stream += "\n\n=============== 🔻 ERROR 🔻 ===============\n\n"

// 		for i in 0 ..< list.count {
// 			if i == list.count - 1 {
// 				stream += "❌ "
// 			} else {
// 				stream += "👇 "
// 			}

// 			// if let r = list[i] as? XError {
// 			// 	stream += "XError[\(r.message)] @ \(r.caller.format())"
// 			// } else {
// 			// 	let r = list[i] as NSError
// 			// 	stream += "NSError[\(r)]"
// 			// }

// 			stream += "\(list[i])"

// 			stream += "\n"
// 			let r = list[i] as NSError
// 			for i in r.userInfo {
// 				stream += "\t\(i.key) = \(i.value)\n"
// 			}

// 			stream += "\n"
// 		}

// 		// Finish with the closing log message
// 		// stream += "===========================================\n\n"

// 		// Print the entire accumulated log
// 		return stream
// 	}
// }
