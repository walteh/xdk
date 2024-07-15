//
//  Engine.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//
//  Inspied by github.com/daltoniam/Starscream by Dalton Cherry
//

import Foundation

public protocol WSEngineDelegate: AnyObject {
	func didReceive(event: WSEvent)
}

public protocol WSEngine {
	func register(delegate: WSEngineDelegate)
	func start(request: URLRequest)
	func stop(closeCode: UInt16)
	func forceStop()
	func write(data: Data, opcode: FrameOpCode, completion: (@Sendable () -> Void)?)
	func write(string: String, completion: (@Sendable () -> Void)?)
}

public final class NativeEngine: NSObject, WSEngine, URLSessionDataDelegate, URLSessionWebSocketDelegate, @unchecked Sendable {
	private var task: URLSessionWebSocketTask?
	private var delegate: WSEngineDelegate?

	public func register(delegate: WSEngineDelegate) {
		self.delegate = delegate
	}

	public func start(request: URLRequest) {
		let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
		self.task = session.webSocketTask(with: request)
		self.doRead()
		self.task?.resume()
	}

	public func stop(closeCode: UInt16) {
		let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
		self.task?.cancel(with: closeCode, reason: nil)
	}

	public func forceStop() {
		self.stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue))
	}

	public func write(string: String, completion: (@Sendable () -> Void)?) {
		self.task?.send(.string(string), completionHandler: { _ in
			completion?()
		})
	}

	public func write(data: Data, opcode: FrameOpCode, completion: (@Sendable () -> Void)?) {
		switch opcode {
		case .binaryFrame:
			self.task?.send(.data(data), completionHandler: { _ in
				completion?()
			})
		case .textFrame:
			let text = String(data: data, encoding: .utf8)!
			self.write(string: text, completion: completion)
		case .ping:
			self.task?.sendPing(pongReceiveHandler: { _ in
				completion?()
			})
		default:
			break // unsupported
		}
	}

	private func doRead() {
		self.task?.receive { [weak self] result in
			switch result {
			case let .success(message):
				switch message {
				case let .string(string):
					self?.broadcast(event: .text(string))
				case let .data(data):
					self?.broadcast(event: .binary(data))
				@unknown default:
					break
				}
			case let .failure(error):
				self?.broadcast(event: .error(error))
				return
			}
			self?.doRead()
		}
	}

	private func broadcast(event: WSEvent) {
		self.delegate?.didReceive(event: event)
	}

	public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
		let p = `protocol` ?? ""
		self.broadcast(event: .connected(["Sec-WebSocket-Protocol": p]))
	}

	public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		var r = ""
		if let d = reason {
			r = String(data: d, encoding: .utf8) ?? ""
		}
		self.broadcast(event: .disconnected(r, UInt16(closeCode.rawValue)))
	}
}
