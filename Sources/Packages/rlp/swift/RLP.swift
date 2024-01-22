//
//  RLP.swift
//  nugg.xyz
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import byte_swift

public enum RLP {
	public enum Error: Swift.Error {
		case stringToData
		case dataToString
		case invalidObject(ofType: Any.Type, expected: Any.Type)

		public var localizedDescription: String {
			switch self {
			case .stringToData: return "Failed to convert String to Data"
			case .dataToString: return "Failed to convert Data to String"
			case let .invalidObject(got, expected):
				return "Invalid object, expected \(expected), but got \(got)"
			}
		}
	}
}

// MARK: Internal helpers

internal extension RLP {
	static func binaryLength(of n: UInt32) -> UInt8 {
		return UInt8(ceil(log10(Double(n)) / log10(Double(UInt8.max))))
	}

	static func encodeLength(_ length: UInt32, offset: UInt8) -> Data {
		if length < 56 {
			let lengthByte = offset + UInt8(length)
			return Data([lengthByte])
		} else {
			let firstByte = offset + 55 + self.binaryLength(of: length)
			var bytes = [firstByte]
			bytes.append(contentsOf: length.byteArrayLittleEndian)
			return Data(bytes)
		}
	}
}

// MARK: Data encoding

public extension RLP {
	static func encode(_ data: Data) -> Data {
		if data.count == 1,
		   0x00 ... 0x7F ~= data[0]
		{
			return data
		} else {
			var result = self.encodeLength(UInt32(data.count), offset: 0x80)
			result.append(contentsOf: data)
			return result
		}
	}

	static func encode(nestedArrayOfData array: [Any]) throws -> Data {
		var output = Data()

		for item in array {
			if let data = item as? Data {
				output.append(self.encode(data))
			} else if let array = item as? [Any] {
				try output.append(self.encode(nestedArrayOfData: array))
			} else {
				throw Error.invalidObject(ofType: Mirror(reflecting: item).subjectType, expected: Data.self)
			}
		}
		let encodedLength = self.encodeLength(UInt32(output.count), offset: 0xC0)
		output.insert(contentsOf: encodedLength, at: 0)
		return output
	}
}

// MARK: String encoding

public extension RLP {
	static func encode(_ string: String, with encoding: String.Encoding = .ascii) throws -> Data {
		guard let data = string.data(using: encoding) else {
			throw Error.stringToData
		}

		let bytes = self.encode(data)

		return bytes
	}

	static func encode(nestedArrayOfString array: [Any], encodeStringsWith encoding: String.Encoding = .ascii) throws -> Data {
		var output = Data()

		for item in array {
			if let string = item as? String {
				try output.append(self.encode(string, with: .ascii))
			} else if let array = item as? [Any] {
				try output.append(self.encode(nestedArrayOfString: array, encodeStringsWith: encoding))
			} else {
				throw Error.invalidObject(ofType: Mirror(reflecting: item).subjectType, expected: String.self)
			}
		}

		return output
	}
}
