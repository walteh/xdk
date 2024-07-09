//
//  Client.swift
//  nugg.xyz
//
//  Created by walter on 12/14/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import XDK

public extension mtx {
	class Client: NSObject {
		let host: URL

		public init(host: String) {
			self.host = .init(string: host)!
		}
	}
}

extension mtx.Client: mtx.API {
	public func Purchase(transaction id: String) async throws -> Bool {
		var req: URLRequest = .init(url: host.appending(path: "/purchase"))

		req.setValue(id, forHTTPHeaderField: "X-Nugg-Utf8-Transaction-ID")

		req.httpMethod = "POST"

		let (_, response) = try await URLSession.shared.data(for: req)

		guard let res = response as? HTTPURLResponse else {
			throw x.error("could not turn response into HTTPURLResponse")
		}

		if res.statusCode != 202 {
			throw x.error("unexpected status code: \(res.statusCode)")
		}

		return true
	}
}
