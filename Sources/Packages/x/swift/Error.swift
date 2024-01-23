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
	static func error(_ str: String, root: (any Swift.Error)? = nil, __file: String = #fileID, __line: Int = #line, __function: String = #function) -> x.Error {
		return x.Error(str, root: root, __file: __file, __line: __line, __function: __function)
	}

	@discardableResult
	static func error(status: OSStatus, __file: String = #fileID, __line: Int = #line, __function: String = #function) -> x.Error {
		return x.Error("OSStatus[\(status)]", __file: __file, __line: __line, __function: __function)
	}

	class Error {
		var _event: LogEvent

		private var dumped = false

		var message: String = ""
		var root: (any Swift.Error)?

		public required convenience init(rawValue: String) {
			self.init(rawValue)
		}

		public func event(_ manip: (LogEvent) -> LogEvent) -> Self {
			self._event = manip(self._event)
			return self
		}

		public init(_ message: String, root: (any Swift.Error)? = nil, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
			self.root = root

			self.message = message
//			self.stack = Thread.callStackSymbols.prefix(upTo: .init(11)).dropLast()
//			self.stack = []
			self._event = LogEvent(.error, __file: __file, __function: __function, __line: __line)
		}
	}
}

extension x.Error: Error, Encodable, RawRepresentable {
	public var rawValue: String {
		return message
	}

	public typealias RawValue = String

	private enum CodingKeys: String, CodingKey {
		case message, root
	}
	

	private func rootList() -> [Swift.Error] {
		// loop through the roots, and append each to a string backwards
		var strs = [Swift.Error]()
		strs += [self]
		var root = self.root
		while root != nil {
			strs += [root!]
			if let r = root as? x.Error {
				root = r.root
			} else {
				root = nil
			}
		}
		strs.reverse()
		return strs
	}

	var localizedDescription: String {
		let strs = self.rootList().map {
			if let errd = $0 as? Self {
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
				result += strs[i] + " ➡️ ❌ "
			} else {
				result += strs[i] + " ➡️ "
			}
		}

		return result
	}

	public func dump() -> String {
		var stream = ""

		let list = self.rootList()

		// Start with the initial log message
		stream += "\n\n‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️ ERROR ‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️\n\n"

		for i in 0 ..< list.count {

			if i == list.count - 1 {
				stream += "❌ "
			} else {
				stream += "⬇️ "
			}

			if let r = list[i] as? x.Error {
				stream += "ERROR[ \(r._event.caller) - \(r.localizedDescription) ]"
			} else {
				stream += list[i].localizedDescription
			}

			stream += "\n"
			if let r = list[i] as? x.Error {
				for i in r._event.metadata {
					stream += "\t\t\(i.key) = \(i.value)\n"
				}
			}
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
		stream += "\n‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️\n"

		// Print the entire accumulated log
		return stream
	}

	@discardableResult
	public func print() -> x.Error {
		Swift.print(self.dump())
		return self
	}
}
