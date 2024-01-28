//
//  Appsync.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import XDK

public protocol AppsyncSubscriptionDelegate: NSObject {
	func onIncoming(payload: Data)
}

public struct Dat: Codable {
	let id: String!
	let type: String!
}

public class NoopListenDelegate: NSObject, AppsyncSubscriptionDelegate {
	public func onIncoming(payload _: Data) {}
}

public class WSAppsyncProvider: WSAsyncProvider {
	public let host: String
	public let token: String
	public let useAPIKey: Bool
	var appsyncDelegate: AppsyncSubscriptionDelegate

	init(host: String, token: String, useAPIKey: Bool) {
		self.host = host
		self.token = token
		self.useAPIKey = useAPIKey
		self.appsyncDelegate = NoopListenDelegate()
	}

	public func connectToAppsync(delegate: AppsyncSubscriptionDelegate) {
		self.appsyncDelegate = delegate
		connect(url: self.appsyncRealtimeEndpoint, protocols: ["graphql-ws"])
	}

	// generateWebSocketKey 16 random characters between a-z and return them as a base64 string
	static func generateWebSocketKey() -> String {
		Data((0 ..< 16).map { _ in UInt8.random(in: 97 ... 122) }).base64URLEncodedString()
	}

	private var authHeaderKey: String {
		self.useAPIKey ? "x-api-key" : "Authorization"
	}

	private var authHeaderValue: String {
		self.useAPIKey ? self.token : self.token
	}

	private var authHeaderObject: String {
		"{\"\(self.authHeaderKey)\":\"\(self.authHeaderValue)\",\"host\":\"\(self.host)\"}"
	}

	private var appsyncRealtimeEndpoint: URL {
		var base = self.host

		if base.contains("amazonaws.com") {
			base = base.replacingOccurrences(of: ".appsync-api.", with: ".appsync-api-realtime.")
		}

		let url = URL(string: "wss://\(base)/graphql/realtime")!

		return url.appending(
			queryItems: [
				.init(name: "header", value: self.authHeaderObject.base64Encoded.string),
				.init(name: "payload", value: "{}".base64Encoded.string),
			])
	}

	func listenSubscriptionPayload() -> String {
		"""
			{
		      "id": "\(WSAppsyncProvider.generateWebSocketKey())",
		      "payload": {
		           "data": "{\\"query\\":\\"subscription Listen { listen {  ksuid entity payload sent pushed } }\\",\\"variables\\":{}}",
		           "extensions": {"authorization": \(self.authHeaderObject)}
		      },
		      "type": "start"
		  }
		"""
	}

	override public func websocketDidConnectCallback() {
		write(message: self.listenSubscriptionPayload())
	}

	override public func websocketDidReceiveDataCallback(data: Data) {
		do {
			let r = try data.toJSON(like: Dat.self)

			if r.type == "data" {
				self.appsyncDelegate.onIncoming(payload: data)
			}
		} catch let error as NSError {
			x.error("problem receiving data", root: error)
		}
	}

	override public func websocketDidDisconnectCallback(error _: Error?) {
		x.log(.warning).send("[ WebSocketDelegate : websocketDidDisconnect ]")
		self.connectToAppsync(delegate: self.appsyncDelegate)
	}
}
