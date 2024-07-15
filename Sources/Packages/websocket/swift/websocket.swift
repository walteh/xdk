//
//  websocket.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//
//  Inspied by github.com/daltoniam/Starscream by Dalton Cherry
//

import Foundation

public enum WSErrorType: Error {
	case compressionError
	case securityError
	case protocolError // There was an error parsing the WebSocket frames
	case serverError
}

public struct WSError: Error {
	public let type: WSErrorType
	public let message: String
	public let code: UInt16

	public init(type: WSErrorType, message: String, code: UInt16) {
		self.type = type
		self.message = message
		self.code = code
	}
}

public protocol WSClient: AnyObject {
	func connect()
	func disconnect(closeCode: UInt16)
	func write(string: String, completion: (@Sendable () -> Void)?)
	func write(stringData: Data, completion: (@Sendable () -> Void)?)
	func write(data: Data, completion: (@Sendable () -> Void)?)
	func write(ping: Data, completion: (@Sendable () -> Void)?)
	func write(pong: Data, completion: (@Sendable () -> Void)?)
}

// implements some of the base behaviors
public extension WSClient {
	func write(string: String) {
		self.write(string: string, completion: nil)
	}

	func write(data: Data) {
		self.write(data: data, completion: nil)
	}

	func write(ping: Data) {
		self.write(ping: ping, completion: nil)
	}

	func write(pong: Data) {
		self.write(pong: pong, completion: nil)
	}

	func disconnect() {
		self.disconnect(closeCode: CloseCode.normal.rawValue)
	}
}

public enum WSEvent {
	case connected([String: String])
	case disconnected(String, UInt16)
	case text(String)
	case binary(Data)
	case pong(Data?)
	case ping(Data?)
	case error(Error?)
	case viabilityChanged(Bool)
	case reconnectSuggested(Bool)
	case cancelled
}

public protocol WSDelegate: AnyObject {
	func didReceive(event: WSEvent, client: WSClient)
}

open class WS: WSClient, WSEngineDelegate {
	private let engine: WSEngine
	public let delegate: WSDelegate
	public let callbackq: DispatchQueue
	public var onEvent: ((WSEvent) -> Void)?

	public let request: URLRequest

	public init(url: URL, protocols: [String] = [], serialq: DispatchQueue, delegate: WSDelegate) {
		var request = URLRequest(url: url)
		request.setValue(protocols.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol")

		self.delegate = delegate
		self.callbackq = DispatchQueue(label: "WS.callbackq", target: serialq)
		self.request = request
		self.engine = NativeEngine()
	}

	public func connect() {
		self.engine.register(delegate: self)
		self.engine.start(request: self.request)
	}

	public func disconnect(closeCode: UInt16 = CloseCode.normal.rawValue) {
		self.engine.stop(closeCode: closeCode)
	}

	public func forceDisconnect() {
		self.engine.forceStop()
	}

	public func write(data: Data, completion: (@Sendable () -> Void)?) {
		self.write(data: data, opcode: .binaryFrame, completion: completion)
	}

	public func write(string: String, completion: (@Sendable () -> Void)?) {
		self.engine.write(string: string, completion: completion)
	}

	public func write(stringData: Data, completion: (@Sendable () -> Void)?) {
		self.write(data: stringData, opcode: .textFrame, completion: completion)
	}

	public func write(ping: Data, completion: (@Sendable () -> Void)?) {
		self.write(data: ping, opcode: .ping, completion: completion)
	}

	public func write(pong: Data, completion: (@Sendable () -> Void)?) {
		self.write(data: pong, opcode: .pong, completion: completion)
	}

	private func write(data: Data, opcode: FrameOpCode, completion: (@Sendable () -> Void)?) {
		self.engine.write(data: data, opcode: opcode, completion: completion)
	}

	// MARK: - EngineDelegate

	public func didReceive(event: WSEvent) {
		self.callbackq.sync { [weak self] in
			guard let s = self else { return }
			s.delegate.didReceive(event: event, client: s)
			s.onEvent?(event)
		}
	}
}
