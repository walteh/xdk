//
//  Codeable.swift
//  nugg.xyz
//
//  Created by walter on 11/6/22.
//

import Foundation

public extension Decodable {
	static func parse<T: Decodable>(str: String) throws -> T {
		try str.data.toJSON(like: T.self)
	}
}

public extension Decodable {
	static func parse<T: Decodable>(base64: String) throws -> T {
		try base64.base64Decoded!.toJSON(like: T.self)
	}
}

public extension Encodable {
	func encodeToJSON() throws -> Data {
		try JSONEncoder().encode(self)
	}
}
