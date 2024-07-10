//
//  Async.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

import XDK

/// Protocol to be implemented by different websocket providers
public protocol WSProvider: ObservableObject {
	func connect(url: URL, protocols: [String])

	/// Disconnects the websocket.
	func disconnect()

	/// Write message to the websocket provider
	/// - Parameter message: Message to write
	func write(message: String)

	/// Returns `true` if the websocket is connected
	var isConnected: Bool { get }

	func websocketDidConnectCallback()

	func websocketDidReceiveDataCallback(data: Data)

	func websocketDidDisconnectCallback(error: Error?)
}

public class WSAsyncProvider: WSProvider {
	let serialq: DispatchQueue

	fileprivate var _socket: WS?

	var socket: WS {
		if self._socket == nil {
			fatalError("WebSocket not initialized")
		}
		return self._socket!
	}

	var _isConnected: Bool
	public var isConnected: Bool {
		self.serialq.sync { self._isConnected }
	}

	public init() {
		let serialq = DispatchQueue(label: "WSAdapter.serialq")
		self._isConnected = false
		self.serialq = serialq
	}

	public func connect(url: URL, protocols: [String]) {
		self.serialq.sync {
			x.log(.debug).send("[ws] connect. Connecting to url")

			self._socket = WS(url: url, protocols: protocols, serialq: self.serialq, delegate: self)
			self._socket?.connect()
		}
	}

	public func disconnect() {
		self.serialq.sync {
			x.log(.debug).send("[ws] socket.disconnect")
			self._socket?.disconnect()
			self._socket = nil
		}
	}

	public func write(message: String) {
		self.serialq.sync {
			x.log(.debug).send("[ws] socket.write - \(message)")
			self._socket?.write(string: message)
		}
	}

	public func websocketDidConnectCallback() {}

	public func websocketDidDisconnectCallback(error _: Error?) {}

	public func websocketDidReceiveDataCallback(data _: Data) {}
}

extension WSAsyncProvider: WSDelegate {
	public func didReceive(event: WSEvent, client: WSClient) {
		x.log(.trace).send("[ws] \(event)")
		switch event {
		case .connected:
			self.websocketDidConnect(socket: client)
		case let .text(string):
			self.websocketDidReceiveMessage(socket: client, text: string)
		case let .binary(data):
			self.websocketDidReceiveData(socket: client, data: data)
		case let .viabilityChanged(viability):
			x.log(.debug).send("[ws] viabilityChanged: \(viability)")
		case let .reconnectSuggested(suggestion):
			x.log(.debug).send("[ws] reconnectSuggested: \(suggestion)")
		case let .disconnected(reason, code):
			self.websocketDidDisconnect(socket: client, error: x.error("websocket disconnected").event { $0.add("reason", reason).add("code", "\(code)") })
		case .cancelled:
			self.websocketDidDisconnect(socket: client, error: x.error("websocket cancelled"))
		case let .error(error):

			self.websocketDidDisconnect(socket: client, error: error != nil ? x.error("websocket error", root: error!) : x.error("unknown websocket error"))
//			case .ping:
//			case .pong:
		default:
			return
		}
	}

	private func websocketDidConnect(socket _: WSClient) {
		x.log(.debug).send("[ws] websocketDidConnect: websocket has been connected.")
		self.serialq.sync {
			self._isConnected = true
			self.websocketDidConnectCallback()
		}
	}

	private func websocketDidDisconnect(socket _: WSClient, error: Error?) {
		if error != nil {
			x.log(.error).err(error).send("websocket error")
		} else {
			x.log(.warning).send("websocket disconnected without an error")
		}

		self.serialq.sync {
			self._isConnected = false
			self.websocketDidDisconnectCallback(error: error)
		}
	}

	private func websocketDidReceiveMessage(socket _: WSClient, text: String) {
		let data = text.data(using: .utf8) ?? Data()
		self.websocketDidReceiveDataCallback(data: data)
	}

	private func websocketDidReceiveData(socket _: WSClient, data: Data) {
		self.websocketDidReceiveDataCallback(data: data)
	}
}
