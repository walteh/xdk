//
//  Data.swift
//  app
//
//  Created by walter on 9/28/22.
//

import Foundation

public extension Data {
	func toJSON<T: Decodable>() throws -> T {
		try self.toJSON(like: T.self)
	}

	func toJSON<T: Decodable>(like _: T.Type) throws -> T {
		do {
			return try JSONDecoder().decode(T.self, from: self)
		} catch {
			throw x.error("problem decoding", root: error)
		}

		// catch let DecodingError.keyNotFound(key, context) {
		// 	let str = "could not find key [\(key)] in JSON: \(context.debugDescription) - codingPath: \(context.codingPath)"
		// 	throw XError(raw: 0x20).with(message: str)
		// } catch let DecodingError.valueNotFound(type, context) {
		// 	let str = "could not find type \(type) in JSON: \(context.debugDescription)  - codingPath: \(context.codingPath)"
		// 	throw RuntimeError(.__0x20__JSONDecodingError__valueNotFound, message: str, want: "\(T.Type.self)", error: context.underlyingError)
		// } catch let DecodingError.typeMismatch(type, context) {
		// 	let str = "type mismatch for type \(type) in JSON: \(context.debugDescription) - codingPath: \(context.codingPath)"
		// 	throw RuntimeError(.__0x20__JSONDecodingError__typeMismatch, message: str, want: "\(T.Type.self)", error: context.underlyingError)
		// } catch let DecodingError.dataCorrupted(context) {
		// 	let str = "data found to be corrupted in JSON: \(context.debugDescription) - codingPath: \(context.codingPath)"
		// 	throw RuntimeError(.__0x20__JSONDecodingError__dataCorrupted, message: str, want: "\(T.Type.self)", error: context.underlyingError)
		// } catch let error as NSError {
		// 	let str = "Error in read(from:ofType:) domain= \(error.domain), description= \(error.localizedDescription)"
		// 	throw RuntimeError(.__0x20__JSONDecodingError__unknown, message: str, want: "\(T.Type.self)", error: error)
		// }
	}
}
