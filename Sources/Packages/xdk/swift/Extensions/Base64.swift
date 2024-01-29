//
//  Base64.swift
//  app
//
//  Created by walter on 9/3/22.
//  Copyright © 2022 nugg.xyz. All rights reserved.
//

import Foundation

enum Base64Error: Error {
	case checkedDecodeFailure(String)
}

extension LosslessStringConvertible {
	var string: String { .init(self) }
}

public extension StringProtocol {
	var data: Data { Data(utf8) }
	func decodeHex() -> Data { String(bytes: self.data, encoding: .ascii)?.data ?? Data() }
	var base64Encoded: Data { self.data.base64EncodedData(options: .endLineWithLineFeed) }
	var base64Decoded: Data? { Data(base64Encoded: string) }
	func base64DecodedChecked() throws -> Data { guard let res = Data(base64Encoded: string) else { throw Base64Error.checkedDecodeFailure(string) }; return res }
}

public extension Sequence<UInt8> {
	var data: Data { .init(self) }
	var base64Decoded: Data? { Data(base64Encoded: self.data) }
	var base64Encoded: Data { self.data.base64EncodedData() }
	var string: String? { String(bytes: self, encoding: .utf8) }
	func utfEncodedString() -> String { String(bytes: self, encoding: .utf8) ?? "" }
}

/// Extension for making base64 representations of `Data` safe for
/// transmitting via URL query parameters
public extension Data {
	/// Instantiates data by decoding a base64url string into base64
	///
	/// - Parameter string: A base64url encoded string
	init?(base64URLEncoded string: String) {
		self.init(base64Encoded: string.toggleBase64URLSafe(on: false))
	}

	/// Encodes the string into a base64url safe representation
	///
	/// - Returns: A string that is base64 encoded but made safe for passing
	///            in as a query parameter into a URL string
	func base64URLEncodedString() -> String {
		return self.base64EncodedString().toggleBase64URLSafe(on: true)
	}
}

public extension String {
	/// Encodes or decodes into a base64url safe representation
	///
	/// - Parameter on: Whether or not the string should be made safe for URL strings
	/// - Returns: if `on`, then a base64url string; if `off` then a base64 string
	func toggleBase64URLSafe(on: Bool) -> String {
		if on {
			// Make base64 string safe for passing into URL query params
			let base64url = self.replacingOccurrences(of: "/", with: "_")
				.replacingOccurrences(of: "+", with: "-")
				.replacingOccurrences(of: "=", with: "")
			return base64url
		} else {
			// Return to base64 encoding
			var base64 = self.replacingOccurrences(of: "_", with: "/")
				.replacingOccurrences(of: "-", with: "+")
			// Add any necessary padding with `=`
			if base64.count % 4 != 0 {
				base64.append(String(repeating: "=", count: 4 - base64.count % 4))
			}
			return base64
		}
	}
}
