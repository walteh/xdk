//
//  XID.swift
//
//
//  Created by walter on 1/28/24.
//

import Foundation
import xid
import Err

// var buf = XIDManager()

public struct XID: Sendable {
	var _bytes: (
		UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
		UInt8, UInt8, UInt8, UInt8
	)

	public static func build() -> XID {
		return XID(fromLib: xid.NewXid())
	}

	static func rebuild(raw: Data) -> Result<XID, Error> {
		return Result { try XID(raw: raw) }
	}

	public static func rebuild(string: String) -> Result<XID, Error> {
		return Result { try XID(string: string) }
	}

	public static func rebuild(utf8: Data) -> Result<XID, Error> {
		return Result { try XID(utf8: utf8) }
	}

	private init(fromLib: xid.Id) {
		let data = fromLib.data
		self._bytes = (
			data[0], data[1], data[2], data[3],
			data[4], data[5], data[6], data[7],
			data[8], data[9], data[10], data[11]
		)
	}

	private func toLib() -> xid.Id {
		return try! xid.NewXid(bytes: Data([
			// we know this wont throw because we are passing exactly 12 bytes
			// also, the only way _bytes is being set is from a lib based xid
			self._bytes.0, self._bytes.1, self._bytes.2, self._bytes.3,
			self._bytes.4, self._bytes.5, self._bytes.6, self._bytes.7,
			self._bytes.8, self._bytes.9, self._bytes.10, self._bytes.11,
		]))
	}
}

public extension XID {
	func utf8() -> Data { return self.string().data(using: .utf8) ?? Data() }
	func string() -> String { return self.description }
}

extension XID: CustomStringConvertible {
	public var description: String {
		return self.toLib().description
	}
}

public extension XID {
	@err private init(raw: Data) throws {

		guard let ok = try xid.NewXid(bytes: raw) else {
			throw x.error("problem converting to lib based xid", root: err)
		}

		self.init(fromLib: ok)
	}

	@err private init(string: String) throws {
		guard let ok = try xid.NewXid(from: string) else {
			throw x.error("problem converting to lib based xid", root: err)
		}

		self.init(fromLib: ok)
	}

	@err private init(utf8: Data) throws {
		guard let ok =  try xid.NewXid(from: utf8) else {
			throw x.error("problem converting to lib based xid", root: err)
		}

		self.init(fromLib: ok)
	}
}

public extension XID {
	func counter() -> Int32 {
		return self.toLib().counter()
	}

	func machineID() -> Data {
		return self.toLib().machineId()
	}

	func pid() -> UInt16 {
		return self.toLib().pid()
	}

	func time() -> Date {
		return self.toLib().time()
	}
}

extension XID: Decodable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		try self.init(string: container.decode(String.self))
	}
}

extension XID: Encodable {
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(String(describing: self))
	}
}

extension XID: Equatable {
	public static func == (lhs: XID, rhs: XID) -> Bool {
		return lhs.string() == rhs.string()
	}
}

private let base32Alphabet = Data("0123456789abcdefghijklmnopqrstuv".utf8)

private let base32DecodeMap: Data = {
	var map = Data(repeating: 0xFF, count: 256)
	for i in 0 ..< base32Alphabet.count {
		map[Data.Index(base32Alphabet[i])] = UInt8(i)
	}

	return map
}()

// extension XID: NSSecureCoding {
// 	static let supportsSecureCoding = true

// 	func encode(with coder: NSCoder) {
// 		coder.encode(self._bytes, forKey: "id")
// 	}

// 	init?(coder: NSCoder) {
// 		let id = coder.decodeObject(of: NSData.self, forKey: "id") as Data
// 		try? self.init(raw: id)
// 	}
// }
