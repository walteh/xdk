//
//  hex.swift
//  nugg.xyz
//
//  Created by walter on 02/28/2023.
//  Copyright © 2023 nugg.xyz LLC. All rights reserved.
//

import Foundation

import byte_swift

public enum xhex {
	public static func ToHexString(_ data: Data, prefixed: Bool = true, uppercase: Bool = false) -> String {
		return toHexString(data, prefixed: prefixed, uppercase: uppercase)
	}

	public static func ToHexData(_ data: Data, uppercase: Bool = false) -> Data {
		return toHexData(data, uppercase: uppercase)
	}
}

/// Uppercase radix16 table.
private let radix16table_uppercase: byte_swift.Bytes = [
	.zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .A, .B, .C, .D, .E, .F,
]

/// Lowercase radix16 table.
private let radix16table_lowercase: byte_swift.Bytes = [
	.zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .a, .b, .c, .d, .e, .f,
]

/// Converts `Data` to a hex-encoded `String`.
///
///     Data("hello".utf8).hexEncodedString() // 68656c6c6f
///
/// - parameters:
///     - uppercase: If `true`, uppercase letters will be used when encoding.
///                  Default value is `false`.
func toHexString(_ data: Data, prefixed: Bool = true, uppercase: Bool = false) -> String {
	return "\(prefixed ? "0x" : "")\(String(bytes: toHexData(data, uppercase: uppercase), encoding: .utf8) ?? "")"
}

/// Applies hex-encoding to `Data`.
///
///     Data("hello".utf8).hexEncodedData() // 68656c6c6f
///
/// - parameters:
///     - uppercase: If `true`, uppercase letters will be used when encoding.
///                  Default value is `false`.
func toHexData(_ data: Data, uppercase: Bool = false) -> Data {
	var bytes = Data()
	bytes.reserveCapacity(data.count * 2)

	let table: byte_swift.Bytes
	if uppercase {
		table = radix16table_uppercase
	} else {
		table = radix16table_lowercase
	}

	for byte in data {
		bytes.append(table[Int(byte / 16)])
		bytes.append(table[Int(byte % 16)])
	}

	return bytes
}
