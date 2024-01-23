//
//  MQTTWebSocket.swift
//  MQTT
//
//  Created by Cyrus Ingraham on 12/13/19.
//

import Foundation
import XDKX

// MARK: - Interfaces

public protocol MQTTWebSocketConnectionDelegate: AnyObject {
	func connection(_ conn: MQTTWebSocketConnection, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Swift.Void)

	func connectionOpened(_ conn: MQTTWebSocketConnection)

	func connectionClosed(_ conn: MQTTWebSocketConnection, withError error: Error?)

	func connection(_ conn: MQTTWebSocketConnection, receivedString string: String)

	func connection(_ conn: MQTTWebSocketConnection, receivedData data: Data)
}

public protocol MQTTWebSocketConnection: NSObjectProtocol {
	var delegate: MQTTWebSocketConnectionDelegate? { get set }

	var queue: DispatchQueue { get set }

	func connect()

	func disconnect()

	func write(data: Data, handler: @escaping (Error?) -> Void)
}

public protocol MQTTWebSocketConnectionBuilder {
	func buildConnection(forURL url: URL, withHeaders headers: [String: String]) throws -> MQTTWebSocketConnection
}

// MARK: - MQTTWebSocket

struct WriteItem: Hashable {
	let uuid = UUID()
	let tag: Int
	let timeout: DispatchWallTime
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.uuid)
	}
}

class ScheduledWriteController {
	private var queue = DispatchQueue(label: "write.ws.mqtt", qos: .default)
	private(set) var scheduledWrites = Set<WriteItem>()

	func insert(_ item: WriteItem) {
		self.queue.sync {
			_ = self.scheduledWrites.insert(item)
		}
	}

	func remove(_ item: WriteItem) -> WriteItem? {
		return self.queue.sync {
			self.scheduledWrites.remove(item)
		}
	}

	func removeAll() {
		self.queue.sync {
			self.scheduledWrites.removeAll()
		}
	}

	func closestTimeout() -> DispatchWallTime? {
		return self.queue.sync {
			self.scheduledWrites.sorted(by: { a, b in a.timeout < b.timeout }).first?.timeout
		}
	}
}

struct ReadItem {
	let tag: Int
	let length: UInt
	let timeout: DispatchWallTime
}

class ScheduledReadController {
	private var queue = DispatchQueue(label: "read.ws.mqtt", qos: .default)
	private var readBuffer = Data()
	private(set) var scheduledReads: [ReadItem] = []

	func append(_ item: ReadItem) {
		self.queue.sync {
			self.scheduledReads.append(item)
		}
	}

	func available() -> Bool {
		return self.queue.sync {
			self.scheduledReads.first?.length ?? UInt.max <= self.readBuffer.count
		}
	}

	func take() -> (Data, Int) {
		self.queue.sync {
			let nextRead = self.scheduledReads.removeFirst()
			let readRange = self.readBuffer.startIndex ..< Data.Index(nextRead.length)
			let readData = self.readBuffer.subdata(in: readRange)
			self.readBuffer.removeSubrange(readRange)
			return (readData, nextRead.tag)
		}
	}

	func removeAll() {
		self.queue.sync {
			self.readBuffer.removeAll()
			self.scheduledReads.removeAll()
		}
	}

	func closestTimeout() -> DispatchWallTime? {
		return self.queue.sync {
			self.scheduledReads.sorted(by: { a, b in a.timeout < b.timeout }).first?.timeout
		}
	}

	func append(_ data: Data) {
		self.queue.sync {
			self.readBuffer.append(data)
		}
	}
}

public class MQTTWebSocket: MQTTSocketProtocol {
	public var enableSSL = false

	public var shouldConnectWithURIOnly = false

	public var headers: [String: String] = [:]

	public typealias ConnectionBuilder = MQTTWebSocketConnectionBuilder

	public struct DefaultConnectionBuilder: ConnectionBuilder {
		public init() {}

		public func buildConnection(forURL url: URL, withHeaders headers: [String: String]) throws -> MQTTWebSocketConnection {
			let config = URLSessionConfiguration.default
			config.httpAdditionalHeaders = headers
			return MQTTWebSocket.FoundationConnection(url: url, config: config)
		}
	}

	public func setDelegate(_ theDelegate: MQTTSocketDelegate?, delegateQueue: DispatchQueue?) {
		self.internalQueue.async {
			self.delegate = theDelegate
			self.delegateQueue = delegateQueue
		}
	}

	let uri: String
	let builder: ConnectionBuilder
	public init(uri: String = "", builder: ConnectionBuilder = MQTTWebSocket.DefaultConnectionBuilder()) {
		self.uri = uri
		self.builder = builder
	}

	public func connect(toHost host: String, onPort port: UInt16) throws {
		try self.connect(toHost: host, onPort: port, withTimeout: -1)
	}

	public func connect(toHost host: String, onPort port: UInt16, withTimeout _: TimeInterval) throws {
		var urlStr = ""

		if self.shouldConnectWithURIOnly {
			urlStr = "\(self.uri)"
		} else {
			urlStr = "\(self.enableSSL ? "wss" : "ws")://\(host):\(port)\(self.uri)"
		}

		guard let url = URL(string: urlStr) else { throw MQTTError.invalidURL }
		self.internalQueue.sync {
			do {
				self.connection?.disconnect()
				self.connection?.delegate = nil
				let newConnection = try builder.buildConnection(forURL: url, withHeaders: self.headers)
				self.connection = newConnection
				newConnection.delegate = self
				newConnection.queue = self.internalQueue
				newConnection.connect()
			} catch {
				x.error(error)
			}
		}
	}

	public func disconnect() {
		self.internalQueue.async {
			// self.reset()
			self.closeConnection(withError: nil)
		}
	}

	public func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
		self.internalQueue.async {
			let newRead = ReadItem(tag: tag, length: length, timeout: (timeout > 0.0) ? .now() + timeout : .distantFuture)
			self.scheduledReads.append(newRead)
			self.checkScheduledReads()
		}
	}

	public func write(_ data: Data, withTimeout timeout: TimeInterval, tag: Int) {
		self.internalQueue.async {
			let newWrite = WriteItem(tag: tag, timeout: (timeout > 0.0) ? .now() + timeout : .distantFuture)
			self.scheduledWrites.insert(newWrite)
			self.checkScheduledWrites()

			self.connection?.write(data: data) { possibleError in
				if let error = possibleError {
					self.closeConnection(withError: error)
				} else {
					guard self.scheduledWrites.remove(newWrite) != nil else { return }

					guard let delegate = self.delegate else { return }
					delegate.socket(self, didWriteDataWithTag: tag)
				}
			}
		}
	}

	var delegate: MQTTSocketDelegate?
	var delegateQueue: DispatchQueue?
	var internalQueue = DispatchQueue(label: "MQTTWebSocket")

	private var connection: MQTTWebSocketConnection?

	private func reset() {
		self.connection?.delegate = nil
		self.connection?.disconnect()
		self.connection = nil

		self.scheduledReads.removeAll()
		self.readTimeoutTimer.reset()

		self.scheduledWrites.removeAll()

		self.writeTimeoutTimer.reset()
	}

	private func closeConnection(withError error: Error?) {
		self.reset()
		__delegate_queue {
			self.delegate?.socketDidDisconnect(self, withError: error)
		}
	}

	private class ReusableTimer {
		let queue: DispatchQueue
		var timer: DispatchSourceTimer?
		private let semaphore = DispatchSemaphore(value: 1)

		init(queue: DispatchQueue) {
			self.queue = queue
		}

		func schedule(wallDeadline: DispatchWallTime, handler: @escaping () -> Void) {
			self.semaphore.wait()
			self.timer?.cancel()
			self.timer = nil
			let newTimer = DispatchSource.makeTimerSource(flags: .strict, queue: self.queue)
			self.timer = newTimer
			newTimer.schedule(wallDeadline: wallDeadline)
			newTimer.setEventHandler(handler: handler)
			newTimer.resume()
			self.semaphore.signal()
		}

		func reset() {
			self.semaphore.wait()
			self.timer?.cancel()
			self.timer = nil
			self.semaphore.signal()
		}
	}

	private var scheduledReads = ScheduledReadController()
	private lazy var readTimeoutTimer = ReusableTimer(queue: internalQueue)
	private func checkScheduledReads() {
		guard let theDelegate = delegate else { return }
		guard let delegateQueue else { return }

		self.readTimeoutTimer.reset()

		while self.scheduledReads.available() {
			let taken = self.scheduledReads.take()
			delegateQueue.async {
				theDelegate.socket(self, didRead: taken.0, withTag: taken.1)
			}
		}

		guard let closestTimeout = scheduledReads.closestTimeout() else { return }

		if closestTimeout < .now() {
			self.closeConnection(withError: MQTTError.readTimeout)
		} else {
			self.readTimeoutTimer.schedule(wallDeadline: closestTimeout) { [weak self] in
				self?.checkScheduledReads()
			}
		}
	}

	private var scheduledWrites = ScheduledWriteController()
	private lazy var writeTimeoutTimer = ReusableTimer(queue: internalQueue)
	private func checkScheduledWrites() {
		self.writeTimeoutTimer.reset()
		guard let closestTimeout = scheduledWrites.closestTimeout() else { return }

		if closestTimeout < .now() {
			self.closeConnection(withError: MQTTError.writeTimeout)
		} else {
			self.writeTimeoutTimer.schedule(wallDeadline: closestTimeout) { [weak self] in
				self?.checkScheduledWrites()
			}
		}
	}
}

extension MQTTWebSocket: MQTTWebSocketConnectionDelegate {
	public func connection(_ conn: MQTTWebSocketConnection, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Swift.Void) {
		guard conn.isEqual(self.connection) else { return }
		if let del = delegate {
			__delegate_queue {
				del.socket(self, didReceive: trust, completionHandler: completionHandler)
			}
		} else {
			completionHandler(false)
		}
	}

	public func connectionOpened(_ conn: MQTTWebSocketConnection) {
		guard conn.isEqual(self.connection) else { return }
		guard let delegate else { return }
		guard let delegateQueue else { return }
		delegateQueue.async {
			delegate.socketConnected(self)
		}
	}

	public func connectionClosed(_ conn: MQTTWebSocketConnection, withError error: Error?) {
		guard conn.isEqual(self.connection) else { return }
		self.closeConnection(withError: error)
	}

	public func connection(_ conn: MQTTWebSocketConnection, receivedString string: String) {
		guard let data = string.data(using: .utf8) else { return }
		self.connection(conn, receivedData: data)
	}

	public func connection(_ conn: MQTTWebSocketConnection, receivedData data: Data) {
		guard conn.isEqual(self.connection) else { return }
		self.scheduledReads.append(data)
		self.checkScheduledReads()
	}
}

// MARK: - MQTTWebSocket.FoundationConnection

public extension MQTTWebSocket {
	class FoundationConnection: NSObject, MQTTWebSocketConnection {
		public weak var delegate: MQTTWebSocketConnectionDelegate?
		public lazy var queue = DispatchQueue(label: "MQTTFoundationWebSocketConnection-\(self.hashValue)")

		var session: URLSession?
		var task: URLSessionWebSocketTask?

		public init(url: URL, config: URLSessionConfiguration) {
			super.init()
			x.log(.debug).msg("opening url session for \(url.absoluteString)")
			let theSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
			self.session = theSession
			self.task = theSession.webSocketTask(with: url, protocols: ["mqtt"])
		}

		public func connect() {
			self.task?.resume()
			self.scheduleRead()
		}

		public func disconnect() {
			self.task?.cancel()
			self.session = nil
			self.task = nil
			self.delegate = nil
		}

		public func write(data: Data, handler: @escaping (Error?) -> Void) {
			self.task?.send(.data(data)) { possibleError in
				handler(possibleError)
			}
		}

		func scheduleRead() {
			self.queue.async {
				guard let task = self.task else { return }
				task.receive { result in
//					x.log(.debug).msg("result received from websocket \(result)")
					self.queue.async {
//						x.log(.debug).msg("result from websocket being processed \(self.delegate.debugDescription)")
						guard let delegate = self.delegate else { return }
						switch result {
						case let .success(message):
							switch message {
							case let .data(data):
								delegate.connection(self, receivedData: data)
							case let .string(string):
								delegate.connection(self, receivedString: string)

							@unknown default: break
							}
							self.scheduleRead()
						case let .failure(error):
							delegate.connectionClosed(self, withError: error)
						}
					}
				}
			}
		}
	}
}

extension MQTTWebSocket.FoundationConnection: URLSessionWebSocketDelegate {
	public func urlSession(_: URLSession, task _: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		queue.async {
			if let trust = challenge.protectionSpace.serverTrust, let delegate = self.delegate {
				delegate.connection(self, didReceive: trust) { shouldTrust in
					completionHandler(shouldTrust ? .performDefaultHandling : .rejectProtectionSpace, nil)
				}
			} else {
				completionHandler(.performDefaultHandling, nil)
			}
		}
	}

	public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol _: String?) {
		queue.async {
			self.delegate?.connectionOpened(self)
		}
	}

	public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason _: Data?) {
		queue.async {
			self.delegate?.connectionClosed(self, withError: MQTTError.FoundationConnection.closed(closeCode))
		}
	}
}

// MARK: - Helper

extension MQTTWebSocket {
	func __delegate_queue(_ fun: @escaping () -> Void) {
		self.delegateQueue?.async { [weak self] in
			guard let _ = self else { return }
			fun()
		}
	}
}
