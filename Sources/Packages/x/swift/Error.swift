//
//  Error.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation

public extension x {
	enum GenericError: Swift.Error {
		case unknown
	}

	@discardableResult
	static func error(_ str: String, root: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> XError {
		return XError(str, root: root, __file: __file, __function: __function, __line: __line)
	}

	@discardableResult
	static func error(status: OSStatus, __file: String = #fileID,  __function: String = #function,__line: UInt = #line) -> XError {
		return XError("OSStatus[\(status)]", __file: __file, __function: __function, __line: __line)
	}
}

public class XError: NSError {
	
	public override var underlyingErrors: [Error] {
		if let r = selfroot {
			return [r]
		}
		return []
	}
	
	let message: String
	let selfroot: NSError?
	
	let caller: Caller
	
	public required convenience init(rawValue: String) {
		self.init(rawValue)
	}

	public init(_ message: String, root: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) {
		if let r = root {
			self.selfroot = r as NSError
		} else {
			self.selfroot = nil
		}

		self.message = message
		self.caller = Caller(file: __file, function: __function, line: __line)
		
		super.init(domain: "XError", code: -6)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

}

public extension NSError {
	
	func info(_ values: [String: Any]) -> NSError {
		var inf = userInfo
		for m in values {
			inf[m.key] = m.value
		}
		return NSError(domain: self.domain, code: self.code, userInfo: inf)
	}
	
	func info(_ key: String, _ value: CustomDebugStringConvertible) -> NSError {
		return info([key: value])
	}
	
	func info(description: String) -> NSError {
		return self.info(NSLocalizedDescriptionKey, description)
	}
	
	func info(failure: String) -> NSError {
		return self.info(NSLocalizedFailureErrorKey, failure)
	}
	
	func info(failureReason: String) -> NSError {
		return self.info(NSLocalizedFailureReasonErrorKey, failureReason)
	}
	
	func info(recoverySuggestion: String) -> NSError {
		return self.info(NSLocalizedRecoverySuggestionErrorKey, recoverySuggestion)
	}
	
	func event(_ manip: (LogEvent) -> LogEvent) -> NSError {
		var event = LogEvent(.error)
		event = manip(event)
		return self.info(event.metadata)
	}
	
//	init(
//		domain: String,
//		code: Int,
//		userInfo dict: [String : Any]? = nil
//	) {
//		
//	}
	
//	var caller: String {
//		
//	}
//
//	
//	@inlinable
//	convenience init(domain: String, code: Int, userInfo dict: [String : Any]? = nil) {
//		self.init(domain: domain, code: code, userInfo: userInfo)
//	}
	
	var root: NSError? {
		if self.underlyingErrors.count == 1 {
			return self.underlyingErrors[0] as NSError
		}
		return nil
	}
	
//	public var typ: String {
//		return "\(type(of: self))"
//	}
	
//	public var rawValue: String {
//		return message
//	}
//
//	public typealias RawValue = String
//
//	private enum CodingKeys: String, CodingKey {
//		case message, root
//	}

	private func rootList() -> [Swift.Error] {
		// loop through the roots, and append each to a string backwards
		var strs = [Swift.Error]()
		strs += [self]
		var root = self.root
		while root != nil {
			strs += [root!]
			root = root!.root
		}
		strs.reverse()
		return strs
	}

	var localizedDescription: String {
		let strs = self.rootList().map {
			if let errd = $0 as? XError {
				return errd.message
			} else {
				return $0.localizedDescription
			}
		}
		Swift.print("HI1", strs)
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

	func dump() -> String {
		var stream = ""

		let list = self.rootList()

		// Start with the initial log message
		stream += "\n\n=============== 🔻 ERROR 🔻 ===============\n\n"

		for i in 0 ..< list.count {
			if i == list.count - 1 {
				stream += "❌ "
			} else {
				stream += "👇 "
			}

			if let r = list[i] as? XError {
				stream += "XError[\(r.message)] @ \(r.caller.format())"
			} else {
				let r = list[i] as NSError
				stream += "NSError[\(r)]"
			}

			stream += "\n"
			let r = list[i] as NSError
			for i in r.userInfo {
				stream += "\t\(i.key) = \(i.value)\n"
			}
//			if let r = list[i] as? XError {
//				for i in r._event.metadata {
//					stream += "\t\(i.key) = \(i.value)\n"
//				}
//			} else {
//				let r = list[i] as NSError
//				for i in r.userInfo {
//					stream += "\t\(i.key) = \(i.value)\n"
//				}
//			}
			stream += "\n"
//			if i == list.count - 1 {
//				// Dump 'self' to the stream
//				Swift.dump(list[i], to: &stream)
//				stream += "\n"
//			}
		}

//
//		// Dump 'self' to the stream
//		Swift.dump(self, to: &stream)

		// Finish with the closing log message
		stream += "===========================================\n"

		// Print the entire accumulated log
		return stream
	}

//	@discardableResult
//	public func print() -> NSError {
//		Swift.print(self.dump())
//		return self
//	}
}
