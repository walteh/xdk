//
//  Data+Pretty.swift
//  nugg.xyz
//
//  Created by walter on 02/28/2023.
//  Copyright © 2023 nugg.xyz LLC. All rights reserved.
//

import Foundation

extension Data {
	var pretty: String { /// NSString gives us a nice sanitized debugDescription
		guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
		      let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .withoutEscapingSlashes, .fragmentsAllowed]),
		      let prettyPrintedString = String(data: data, encoding: .utf8) else { return "{\"oops\": \"could not parse json\"" }
		return prettyPrintedString
	}
}
