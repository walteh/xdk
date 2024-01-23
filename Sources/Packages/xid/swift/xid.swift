
import Foundation

import XDKX

var buf = XIDManager()

public struct XID {
	var _bytes: (
		UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
		UInt8, UInt8, UInt8, UInt8
	)

	public static func build() -> XID {
		return buf.next()
	}

	static func rebuild(raw: Data) throws -> XID {
		return try XID(raw: raw)
	}

	public static func rebuild(string: String) throws -> XID {
		return try XID(string: string)
	}

	public static func rebuild(utf8: Data) throws -> XID {
		return try XID(utf8: utf8)
	}
}

public extension XID {
	func data() -> Data { return self.string().data(using: .utf8) ?? Data() }
	func string() -> String { return self.description }
}

public extension XID {
	private init(raw: Data) throws {
		if raw.count != 12 {
			throw x.error(XIDError.InvalidRawDataLength(have: raw.count, want: 12))
		}

		self._bytes = (
			raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7],
			raw[8], raw[9], raw[10], raw[11]
		)
	}

	private init(string: String) throws {
		if string.count != 20 {
			throw x.error(XIDError.InvalidStringLength(have: string.count, want: 20))
		}

		guard let data = string.data(using: .utf8) else {
			throw x.error(XIDError.invalidID)
		}

		try self.init(utf8: data)
	}

	private init(utf8: Data) throws {
		if utf8.count != 20 {
			throw XIDError.invalidID
		}

		let from = utf8

//		self._bytes = Data(repeating: 0x00, count: 12)
		self._bytes.11 = base32DecodeMap[Data.Index(from[17])] << 6 | base32DecodeMap[Data.Index(from[18])] << 1 | base32DecodeMap[Data.Index(from[19])] >> 4
		self._bytes.10 = base32DecodeMap[Data.Index(from[16])] << 3 | base32DecodeMap[Data.Index(from[17])] >> 2
		self._bytes.9 = base32DecodeMap[Data.Index(from[14])] << 5 | base32DecodeMap[Data.Index(from[15])]
		self._bytes.8 = base32DecodeMap[Data.Index(from[12])] << 7 | base32DecodeMap[Data.Index(from[13])] << 2 | base32DecodeMap[Data.Index(from[14])] >> 3
		self._bytes.7 = base32DecodeMap[Data.Index(from[11])] << 4 | base32DecodeMap[Data.Index(from[12])] >> 1
		self._bytes.6 = base32DecodeMap[Data.Index(from[9])] << 6 | base32DecodeMap[Data.Index(from[10])] << 1 | base32DecodeMap[Data.Index(from[11])] >> 4
		self._bytes.5 = base32DecodeMap[Data.Index(from[8])] << 3 | base32DecodeMap[Data.Index(from[9])] >> 2
		self._bytes.4 = base32DecodeMap[Data.Index(from[6])] << 5 | base32DecodeMap[Data.Index(from[7])]
		self._bytes.3 = base32DecodeMap[Data.Index(from[4])] << 7 | base32DecodeMap[Data.Index(from[5])] << 2 | base32DecodeMap[Data.Index(from[6])] >> 3
		self._bytes.2 = base32DecodeMap[Data.Index(from[3])] << 4 | base32DecodeMap[Data.Index(from[4])] >> 1
		self._bytes.1 = base32DecodeMap[Data.Index(from[1])] << 6 | base32DecodeMap[Data.Index(from[2])] << 1 | base32DecodeMap[Data.Index(from[3])] >> 4
		self._bytes.0 = base32DecodeMap[Data.Index(from[0])] << 3 | base32DecodeMap[Data.Index(from[1])] >> 2

		// Validate that there are no padding in data that would cause the re-encoded id to not equal data.
		var check = Data(repeating: 0x00, count: 4)
		check[3] = base32Alphabet[Data.Index((self._bytes.11 << 4) & 0x1F)]
		check[2] = base32Alphabet[Data.Index((self._bytes.11 >> 1) & 0x1F)]
		check[1] = base32Alphabet[Data.Index((self._bytes.11 >> 6) & 0x1F | (self._bytes.10 << 2) & 0x1F)]
		check[0] = base32Alphabet[Data.Index(self._bytes.10 >> 3)]

		if check != from[16 ... 19] {
			throw x.error(XIDError.decodeValidationFailure)
		}
	}
}

public extension XID {
	func counter() -> Int32 {
		return Int32(
			UInt32(self.data()[9]) << 16 | UInt32(self.data()[10]) << 8 | UInt32(self.data()[11])
		)
	}

	func machineID() -> Data {
		return Data(self.data()[4 ... 6])
	}

	func pid() -> UInt16 {
		let pid: UInt16 = withUnsafeBytes(of: Data(data()[7 ... 8])) { ptr in
			let n = ptr.load(as: UInt16.self)
			return UInt16(bigEndian: n)
		}

		return pid
	}

	func time() -> Date {
		let t: Date = withUnsafeBytes(of: Data(data()[0 ... 3])) { ptr in
			let n = ptr.load(as: UInt32.self)
			return Date(timeIntervalSince1970: TimeInterval(UInt32(bigEndian: n)))
		}

		return t
	}
}

extension XID: CustomStringConvertible {
	public var description: String {
//		if self._bytes.count != 12 {
//			return ""
//		}

		// base32hex encoding
		var chars = Data(repeating: 0x00, count: 20)
		chars[19] = base32Alphabet[Data.Index((self._bytes.11 << 4) & 0x1F)]
		chars[18] = base32Alphabet[Data.Index((self._bytes.11 >> 1) & 0x1F)]
		chars[17] = base32Alphabet[Data.Index((self._bytes.11 >> 6) & 0x1F | (self._bytes.10 << 2) & 0x1F)]
		chars[16] = base32Alphabet[Data.Index(self._bytes.10 >> 3)]
		chars[15] = base32Alphabet[Data.Index(self._bytes.9 & 0x1F)]
		chars[14] = base32Alphabet[Data.Index((self._bytes.9 >> 5) | (self._bytes.8 << 3) & 0x1F)]
		chars[13] = base32Alphabet[Data.Index((self._bytes.8 >> 2) & 0x1F)]
		chars[12] = base32Alphabet[Data.Index(self._bytes.8 >> 7 | (self._bytes.7 << 1) & 0x1F)]
		chars[11] = base32Alphabet[Data.Index((self._bytes.7 >> 4) & 0x1F | (self._bytes.6 << 4) & 0x1F)]
		chars[10] = base32Alphabet[Data.Index((self._bytes.6 >> 1) & 0x1F)]
		chars[9] = base32Alphabet[Data.Index((self._bytes.6 >> 6) & 0x1F | (self._bytes.5 << 2) & 0x1F)]
		chars[8] = base32Alphabet[Data.Index(self._bytes.5 >> 3)]
		chars[7] = base32Alphabet[Data.Index(self._bytes.4 & 0x1F)]
		chars[6] = base32Alphabet[Data.Index(self._bytes.4 >> 5 | (self._bytes.3 << 3) & 0x1F)]
		chars[5] = base32Alphabet[Data.Index((self._bytes.3 >> 2) & 0x1F)]
		chars[4] = base32Alphabet[Data.Index(self._bytes.3 >> 7 | (self._bytes.2 << 1) & 0x1F)]
		chars[3] = base32Alphabet[Data.Index((self._bytes.2 >> 4) & 0x1F | (self._bytes.1 << 4) & 0x1F)]
		chars[2] = base32Alphabet[Data.Index((self._bytes.1 >> 1) & 0x1F)]
		chars[1] = base32Alphabet[Data.Index((self._bytes.1 >> 6) & 0x1F | (self._bytes.0 << 2) & 0x1F)]
		chars[0] = base32Alphabet[Data.Index(self._bytes.0 >> 3)]

		return String(bytes: chars, encoding: .utf8) ?? ""
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
//	static var supportsSecureCoding = true
//
//	func encode(with coder: NSCoder) {
//		coder.encode(self._bytes, forKey: "id")
//	}
//
//	init?(coder: NSCoder) {
//		let id = coder.decodeObject(of: NSData.self, forKey: "id") as Data
//		try? self.init(raw: id)
//	}
// }
