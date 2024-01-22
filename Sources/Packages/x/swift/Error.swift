//
//  File.swift
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
	static func error(_ str: String, __file: String = #fileID, __line: Int = #line, __function: String = #function) -> x.Error {
		return x.Error(nil, message: str, __file: __file, __line: __line, __function: __function)
	}

	@discardableResult
	static func error<A: Swift.Error>(custom _: A? = nil, _ err: A, _ message: String = "wrapped", __file: String = #fileID, __line: Int = #line, __function: String = #function) -> x.Error {
		if let err = err as? x.Error {
			err.appendRoot(x.Error(nil, custom: err, message: message, __file: __file, __line: __line, __function: __function))
			return err
		}
		return x.Error(err, message: message, __file: __file, __line: __line, __function: __function)
	}

	class Error {
		public var rawValue: String

		var kv: [String: String] = [:]

		private var dumped = false

		let code: Int
		var message: String = ""
		var caller: String = "unknown.swift:0"
		let stack: [String]
		var root: (any Swift.Error)?
		var roots: [Swift.Error] = []
		var lastAppend: (any Swift.Error)?

		public func appendRoot(_ err: some Swift.Error) {
			self.lastAppend = err
			self.roots.append(err)
		}

		public static func Log(_ error: Swift.Error, _ message: String) {
			let me = x.Error.wrap(error, message: message)
			print(me.localizedDescription)
		}

		public static func Wrap(_ error: Swift.Error, _ message: String? = nil) -> Swift.Error {
			return x.Error.wrap(error, message: message == nil ? "wrapped" : message!)
		}

		public required convenience init(rawValue: String) {
			self.init(nil, message: rawValue)
			self.withCaller(__file: #fileID, __line: #line, __function: #function)
		}

		public init(_ root: (any Swift.Error)?, custom: Swift.Error? = nil, message: String, __file: String = #fileID, __line: Int = #line, __function: String = #function) {
			if let custom {
				self.rawValue = (custom.localizedDescription)
				self.code = (custom as NSError).code
				self.root = custom
				if let root {
					self.roots.append(root)
				}
			} else if let root {
				self.rawValue = (root as NSError).debugDescription
				self.code = (root as NSError).code
				self.root = root
			} else {
				self.rawValue = message
				self.code = 0
				self.root = nil
			}

			self.message = message
//			self.stack = Thread.callStackSymbols.prefix(upTo: .init(11)).dropLast()
			self.stack = []
			self.withCaller(__file: __file, __line: __line, __function: __function)

//			x.log(.error, self,__file: __file, __line: __line, __function: __function)
		}
	}
}

extension x.Error: Error, Encodable, RawRepresentable {
	public typealias RawValue = String

	private enum CodingKeys: String, CodingKey {
		case kv, code, message, caller, roots
	}

	@discardableResult
	public static func wrap(_ root: any Error, message: String = "wrapped") -> x.Error {
		return x.Error(root, message: message, __file: #fileID, __line: #line, __function: #function)
	}

	@discardableResult
	public func with(message str: String) -> x.Error {
		self.message = str
		return self
	}

	@discardableResult
	public func with(key: String, _ value: String) -> x.Error {
		self.kv.updateValue(value, forKey: key)
		return self
	}

	@discardableResult
	public func withCaller(__file: String = #fileID, __line: Int = #line, __function _: String = #function) -> x.Error {
		self.caller = "\(__file):\(__line)"
		return self
	}

	var localizedDescription: String {
//		var real = self.getRoots()
//		let me = real.removeFirst()
//		me.roots = real
		let enc = try! JSONEncoder().encode(self)
		return String(data: enc, encoding: .utf8) ?? ""
	}

	@discardableResult
	public func log() -> x.Error {
		if !dumped {
			print("‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️ ERROR ‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️")
//			print("caller: \(error.caller)")
			print()
			dump(self)
			print()
			// print(String(format: "%@ | %@ | %@", "ERR", Thread.current.queueName, self.code))
			// print(Data().sha3(.ethereum).x.hexEncodedString())
			// print()
			print("‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️‼️")
			dumped = true
		}
		return self
	}

//	func getRoots() -> [x.Error] {
//		let ok = true
//		var s: [x.Error] = []
//		var wrk = self
//		while ok {
//			s.append(wrk)
//			if let r = wrk.root {
//				if let z = r as? x.Error {
//					wrk = z
//				} else {
//					wrk = x.Error(r, message: "wrapped")
//				}
//				continue
//			} else {
//				break
//			}
//		}
//
//		return s.reversed()
//	}
}
