//
//  MQTT5.swift
//  MQTT5
//
//  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
//  Copyright (c) 2015 emqx.io. All rights reserved.
//

import Foundation
import XDKX

/**
 * Connection State
 */
@objc public enum MQTTConnState: UInt8, CustomStringConvertible {
	case disconnected = 0
	case connecting
	case connected

	public var description: String {
		switch self {
		case .connecting: return "connecting"
		case .connected: return "connected"
		case .disconnected: return "disconnected"
		}
	}
}

/// MQTT5 Delegate
public protocol MQTT5Delegate {
	func didConnect(_ mqtt5: mqtt.API, ack: MQTTCONNACKReasonCode, data: MQTTDecodeConnAck?)
	func didPublish(_ mqtt5: mqtt.API, message: MQTT5Message, id: UInt16)
	func didPublish(_ mqtt5: mqtt.API, ack: UInt16, data: MQTTDecodePubAck?)
	func didPublish(_ mqtt5: mqtt.API, rec: UInt16, data: MQTTDecodePubRec?)
	func didReceive(_ mqtt5: mqtt.API, message: MQTT5Message, id: UInt16, data: MQTTDecodePublish?)
	func didSubscribe(_ mqtt5: mqtt.API, topics: NSDictionary, failed: [String], data: MQTTDecodeSubAck?)
	func didUnsubscribe(_ mqtt5: mqtt.API, topics: [String], data: MQTTDecodeUnsubAck?)
	func didReceiveDisconnect(_ mqtt5: mqtt.API, reasonCode: MQTTDISCONNECTReasonCode)
	func didReceiveAuth(_ mqtt5: mqtt.API, reasonCode: MQTTAUTHReasonCode)
	func didPing(_ mqtt5: mqtt.API)
	func didReceivePong(_ mqtt5: mqtt.API)
	func didDisconnect(_ mqtt5: mqtt.API, withError err: Error?)

	/// Manually validate SSL/TLS server certificate.
	/// This method will be called if enable  `allowUntrustCACertificate`
	func didReceive(_ mqtt5: mqtt.API, trust: SecTrust, completionHandler: @escaping (Bool) -> Void)
	func didPublish(_ mqtt5: mqtt.API, complete: UInt16, data: MQTTDecodePubComp?)
	func didStateChange(_ mqtt5: mqtt.API, to state: MQTTConnState)
}

/// MQTT Client
///
/// - Note: GCDAsyncSocket need delegate to extend NSObject
public class MQTT5: NSObject, mqtt.API {
	public var delegate: MQTT5Delegate?

	private var version = "5.0"

	public var host = "localhost"

	public var port: UInt16 = 1883

	public var clientID: String

	public var username: String?

	public var password: String?

	/// Clean Session flag. Default is true
	///
	/// - TODO: What's behavior each Clean Session flags???
	public var cleanSession = true

	/// Setup a **Last Will Message** to client before connecting to broker
	public var willMessage: MQTT5Message?

	/// Enable backgounding socket if running on iOS platform. Default is true
	///
	/// - Note:
	public var backgroundOnSocket: Bool {
		get { return (self.socket as? MQTTSocket)?.backgroundOnSocket ?? true }
		set { (self.socket as? MQTTSocket)?.backgroundOnSocket = newValue }
	}

	/// Delegate Executed queue. Default is `DispatchQueue.main`
	///
	/// The delegate/closure callback function will be committed asynchronously to it
	public var delegateQueue = DispatchQueue.main

	public var connState = MQTTConnState.disconnected {
		didSet {
			__delegate_queue {
				self.delegate?.didStateChange(self, to: self.connState)
				self.didChangeState(self, self.connState)
			}
		}
	}

	// deliver
	private var deliver = MQTTDeliver()

	/// Re-deliver the un-acked messages
	public var deliverTimeout: Double {
		get { return self.deliver.retryTimeInterval }
		set { self.deliver.retryTimeInterval = newValue }
	}

	/// Message queue size. default 1000
	///
	/// The new publishing messages of Qos1/Qos2 will be drop, if the queue is full
	public var messageQueueSize: UInt {
		get { return self.deliver.mqueueSize }
		set { self.deliver.mqueueSize = newValue }
	}

	/// In-flight window size. default 10
	public var inflightWindowSize: UInt {
		get { return self.deliver.inflightWindowSize }
		set { self.deliver.inflightWindowSize = newValue }
	}

	/// Keep alive time interval
	public var keepAlive: UInt16 = 60
	private var aliveTimer: MQTTTimer?

	/// Enable auto-reconnect mechanism
	public var autoReconnect = false

	/// Reconnect time interval
	///
	/// - note: This value will be increased with `autoReconnectTimeInterval *= 2`
	///         if reconnect failed
	public var autoReconnectTimeInterval: UInt16 = 1 // starts from 1 second

	/// Maximum auto reconnect time interval
	///
	/// The timer starts from `autoReconnectTimeInterval` second and grows exponentially until this value
	/// After that, it uses this value for subsequent requests.
	public var maxAutoReconnectTimeInterval: UInt16 = 128 // 128 seconds

	/// 3.1.2.11 CONNECT Properties
	public var connectProperties: MQTTConnectProperties?

	/// 3.15.2.2 AUTH Properties
	public var authProperties: MQTTAuthProperties?

	private var reconnectTimeInterval: UInt16 = 0

	private var autoReconnTimer: MQTTTimer?
	private var is_internal_disconnected = false

	/// Console log level
	public var logLevel: MQTTLoggerLevel {
		get {
			return MQTTLoggerLevel.debug
		}
		set {
			MQTTLogger.logger.minLevel = newValue
		}
	}

	/// Enable SSL connection
	public var enableSSL: Bool {
		get { return self.socket.enableSSL }
		set { self.socket.enableSSL = newValue }
	}

	///
	public var sslSettings: [String: NSObject]? {
		get { return (self.socket as? MQTTSocket)?.sslSettings ?? nil }
		set { (self.socket as? MQTTSocket)?.sslSettings = newValue }
	}

	/// Allow self-signed ca certificate.
	///
	/// Default is false
	public var allowUntrustCACertificate: Bool {
		get { return (self.socket as? MQTTSocket)?.allowUntrustCACertificate ?? false }
		set { (self.socket as? MQTTSocket)?.allowUntrustCACertificate = newValue }
	}

	/// The subscribed topics in current communication
	public var subscriptions: [String: MQTTQoS] = [:]

	fileprivate var subscriptionsWaitingAck: [UInt16: [MQTTSubscription]] = [:]
	fileprivate var unsubscriptionsWaitingAck: [UInt16: [MQTTSubscription]] = [:]

	/// Sending messages
	fileprivate var sendingMessages: [UInt16: MQTT5Message] = [:]

	/// message id counter
	private var _msgid: UInt16 = 0
	fileprivate var socket: MQTTSocketProtocol
	fileprivate var reader: MQTTReader?

	// Closures
	public var didConnectAck: (MQTT5, MQTTCONNACKReasonCode, MQTTDecodeConnAck?) -> Void = { _, _, _ in }
	public var didPublishMessage: (MQTT5, MQTT5Message, UInt16) -> Void = { _, _, _ in }
	public var didPublishAck: (MQTT5, UInt16, MQTTDecodePubAck?) -> Void = { _, _, _ in }
	public var didPublishRec: (MQTT5, UInt16, MQTTDecodePubRec?) -> Void = { _, _, _ in }
	public var didReceiveMessage: (MQTT5, MQTT5Message, UInt16, MQTTDecodePublish?) -> Void = { _, _, _, _ in }
	public var didSubscribeTopics: (MQTT5, NSDictionary, [String], MQTTDecodeSubAck?) -> Void = { _, _, _, _ in }
	public var didUnsubscribeTopics: (MQTT5, [String], MQTTDecodeUnsubAck?) -> Void = { _, _, _ in }
	public var didPing: (MQTT5) -> Void = { _ in }
	public var didReceivePong: (MQTT5) -> Void = { _ in }
	public var didDisconnect: (MQTT5, Error?) -> Void = { _, _ in }
	public var didDisconnectReasonCode: (MQTT5, MQTTDISCONNECTReasonCode) -> Void = { _, _ in }
	public var didAuthReasonCode: (MQTT5, MQTTAUTHReasonCode) -> Void = { _, _ in }
	public var didReceiveTrust: (MQTT5, SecTrust, @escaping (Bool) -> Swift.Void) -> Void = { _, _, _ in }
	public var didCompletePublish: (MQTT5, UInt16, MQTTDecodePubComp?) -> Void = { _, _, _ in }
	public var didChangeState: (MQTT5, MQTTConnState) -> Void = { _, _ in }

	/// Initial client object
	///
	/// - Parameters:
	///   - clientID: Client Identifier
	///   - host: The MQTT broker host domain or IP address. Default is "localhost"
	///   - port: The MQTT service port of host. Default is 1883
	public init(clientID: String, host: String = "localhost", port: UInt16 = 1883, socket: MQTTSocketProtocol = MQTTSocket()) {
		self.clientID = clientID
		self.host = host
		self.port = port
		self.socket = socket
		super.init()
		self.deliver.delegate = self
		if let storage = MQTTStorage() {
			storage.setMQTTVersion("5.0")
		} else {
			printWarning("Localstorage initial failed for key: \(clientID)")
		}
	}

	deinit {
		aliveTimer?.suspend()
		autoReconnTimer?.suspend()

		socket.setDelegate(nil, delegateQueue: nil)
		socket.disconnect()
	}

	fileprivate func send(_ frame: Frame, tag: Int = 0) {
		printDebug("SEND: \(frame)")
		let data = frame.bytes(version: self.version)
		self.socket.write(Data(bytes: data, count: data.count), withTimeout: 5, tag: tag)
	}

	fileprivate func sendConnectFrame() {
		var connect = FrameConnect(clientID: clientID)
		connect.keepAlive = self.keepAlive
		connect.username = self.username
		connect.password = self.password
		connect.willMsg5 = self.willMessage
		connect.cleansess = self.cleanSession

		connect.connectProperties = self.connectProperties

		self.send(connect)
		self.reader!.start()
	}

	fileprivate func nextMessageID() -> UInt16 {
		if self._msgid == UInt16.max {
			self._msgid = 0
		}
		self._msgid += 1
		return self._msgid
	}

	fileprivate func puback(_ type: FrameType, msgid: UInt16) {
		switch type {
		case .puback:
			self.send(FramePubAck(msgid: msgid, reasonCode: MQTTPUBACKReasonCode.success))
		case .pubrec:
			self.send(FramePubRec(msgid: msgid, reasonCode: MQTTPUBRECReasonCode.success))
		case .pubcomp:
			self.send(FramePubComp(msgid: msgid, reasonCode: MQTTPUBCOMPReasonCode.success))
		default: return
		}
	}

	/// Connect to MQTT broker
	///
	/// - Returns:
	///   - Bool: It indicates whether successfully calling socket connect function.
	///           Not yet established correct MQTT session
	public func connect() -> Bool {
		return self.connect(timeout: -1)
	}

	/// Connect to MQTT broker
	/// - Parameters:
	///   - timeout: Connect timeout
	/// - Returns:
	///   - Bool: It indicates whether successfully calling socket connect function.
	///           Not yet established correct MQTT session
	public func connect(timeout: TimeInterval) -> Bool {
		self.socket.setDelegate(self, delegateQueue: self.delegateQueue)
		self.reader = MQTTReader(socket: self.socket, delegate: self)
		printDebug("connecting to socket @ \(self.host):\(self.port)")
		do {
			if timeout > 0 {
				try self.socket.connect(toHost: self.host, onPort: self.port, withTimeout: timeout)
			} else {
				try self.socket.connect(toHost: self.host, onPort: self.port)
			}

			printDebug("socket connected")

			self.delegateQueue.async { [weak self] in
				guard let self else { return }
				self.connState = .connecting
			}

			return true
		} catch let error as NSError {
			printError("socket connect error: \(error.description)")
			return false
		}
	}

	/// Send a DISCONNECT packet to the broker then close the connection
	///
	/// - Note: Only can be called from outside.
	///         If you want to disconnect from inside framework, call internal_disconnect()
	///         disconnect expectedly
	public func disconnect() {
		self.internal_disconnect()
		self.is_internal_disconnected = false
	}

	public func disconnect(reasonCode: MQTTDISCONNECTReasonCode, userProperties: [String: String]) {
		self.internal_disconnect_withProperties(reasonCode: reasonCode, userProperties: userProperties)
		self.is_internal_disconnected = false
	}

	/// Disconnect unexpectedly
	func internal_disconnect() {
		self.is_internal_disconnected = true
		self.send(FrameDisconnect(disconnectReasonCode: MQTTDISCONNECTReasonCode.normalDisconnection), tag: -0xE0)
		self.socket.disconnect()
	}

	func internal_disconnect_withProperties(reasonCode: MQTTDISCONNECTReasonCode, userProperties: [String: String]) {
		self.is_internal_disconnected = true
		var frameDisconnect = FrameDisconnect(disconnectReasonCode: reasonCode)
		frameDisconnect.userProperties = userProperties
		self.send(frameDisconnect, tag: -0xE0)
		self.socket.disconnect()
	}

	/// Send a PING request to broker
	public func ping() {
		printDebug("ping")
		self.send(FramePingReq(), tag: -0xC0)

		__delegate_queue {
			self.delegate?.didPing(self)
			self.didPing(self)
		}
	}

	/// Publish a message to broker
	///
	/// - Parameters:
	///    - topic: Topic Name. It can not contain '#', '+' wildcards
	///    - string: Payload string
	///    - qos: Qos. Default is Qos1
	///    - retained: Retained flag. Mark this message is a retained message. default is false
	///    - properties: Publish Properties
	/// - Returns:
	///     - 0 will be returned, if the message's qos is qos0
	///     - 1-65535 will be returned, if the messages's qos is qos1/qos2
	///     - -1 will be returned, if the messages queue is full
	@discardableResult
	public func publish(topic: String, withString string: String, qos: MQTTQoS = .qos1, DUP: Bool = false, retained: Bool = false, properties: MQTTPublishProperties) -> Int {
		var fixQus = qos
		if !DUP {
			fixQus = .qos0
		}
		let message = MQTT5Message(topic: topic, string: string, qos: fixQus, retained: retained)
		return self.publish(message: message, DUP: DUP, retained: retained, properties: properties)
	}

	/// Publish a message to broker
	///
	/// - Parameters:
	///   - message: Message
	///   - properties: Publish Properties
	@discardableResult
	public func publish(message: MQTT5Message, DUP: Bool = false, retained _: Bool = false, properties: MQTTPublishProperties) -> Int {
		let msgid: UInt16 = if message.qos == .qos0 {
			0
		} else {
			self.nextMessageID()
		}

		printDebug("message.topic \(message.topic)   = message.payload \(message.payload)")

		var frame = FramePublish(topic: message.topic,
		                         payload: message.payload,
		                         qos: message.qos,
		                         msgid: msgid)
		frame.qos = message.qos
		frame.dup = DUP
		frame.publishProperties = properties
		frame.retained = message.retained

		self.delegateQueue.async {
			self.sendingMessages[msgid] = message
		}

		// Push frame to deliver message queue
		guard self.deliver.add(frame) else {
			self.delegateQueue.async {
				self.sendingMessages.removeValue(forKey: msgid)
			}
			return -1
		}

		return Int(msgid)
	}

	/// Subscribe a `<Topic Name>/<Topic Filter>`
	///
	/// - Parameters:
	///   - topic: Topic Name or Topic Filter
	///   - qos: Qos. Default is qos1
	public func subscribe(topic: String, qos: MQTTQoS = .qos1) {
		let filter = MQTTSubscription(topic: topic, qos: qos)
		return self.subscribe(topics: [filter])
	}

	/// Subscribe a lists of topics
	///
	/// - Parameters:
	///   - topics: A list of tuples presented by `(<Topic Names>/<Topic Filters>, Qos)`
	public func subscribe(topics: [MQTTSubscription]) {
		let msgid = self.nextMessageID()
		let frame = FrameSubscribe(msgid: msgid, subscriptionList: topics)
		self.send(frame, tag: Int(msgid))
		self.subscriptionsWaitingAck[msgid] = topics
	}

	/// Unsubscribe a Topic
	///
	/// - Parameters:
	///   - topic: A Topic Name or Topic Filter
	public func unsubscribe(topic: String) {
		let filter = MQTTSubscription(topic: topic)
		return self.unsubscribe(topics: [filter])
	}

	/// Unsubscribe a list of topics
	///
	/// - Parameters:
	///   - topics: A list of `<Topic Names>/<Topic Filters>`
	public func unsubscribe(topics: [MQTTSubscription]) {
		let msgid = self.nextMessageID()
		let frame = FrameUnsubscribe(msgid: msgid, topics: topics)
		self.unsubscriptionsWaitingAck[msgid] = topics
		self.send(frame, tag: Int(msgid))
	}

	///  Authentication exchange
	///
	///
	public func auth(reasonCode: MQTTAUTHReasonCode, authProperties: MQTTAuthProperties) {
		printDebug("auth")
		let frame = FrameAuth(reasonCode: reasonCode, authProperties: authProperties)

		self.send(frame)
	}
}

// MARK: MQTTDeliverProtocol

extension MQTT5: MQTTDeliverProtocol {
	func deliver(_: MQTTDeliver, wantToSend frame: Frame) {
		if let publish = frame as? FramePublish {
			let msgid = publish.msgid
			guard let message = sendingMessages[msgid] else {
				printError("Want send \(frame), but not found in MQTT5 cache")
				return
			}

			self.send(publish, tag: Int(msgid))

			self.delegate?.didPublish(self, message: message, id: msgid)
			self.didPublishMessage(self, message, msgid)

		} else if let pubrel = frame as? FramePubRel {
			// -- Send PUBREL
			self.send(pubrel, tag: Int(pubrel.msgid))
		}
	}
}

extension MQTT5 {
	func __delegate_queue(_ fun: @escaping () -> Void) {
		self.delegateQueue.async { [weak self] in
			guard let _ = self else { return }
			fun()
		}
	}
}

// MARK: - MQTTSocketDelegate

extension MQTT5: MQTTSocketDelegate {
	public func socketConnected(_: MQTTSocketProtocol) {
		printDebug("socketConnected")
		self.sendConnectFrame()
	}

	public func socket(_: MQTTSocketProtocol,
	                   didReceive trust: SecTrust,
	                   completionHandler: @escaping (Bool) -> Swift.Void)
	{
		printDebug("Call the SSL/TLS manually validating function")
		self.delegate?.didReceive(self, trust: trust, completionHandler: completionHandler)
		self.didReceiveTrust(self, trust, completionHandler)
	}

	// ?
	public func socketDidSecure() {
		printDebug("Socket has successfully completed SSL/TLS negotiation")
		self.sendConnectFrame()
	}

	public func socket(_: MQTTSocketProtocol, didWriteDataWithTag tag: Int) {
		// XXX: How to print writed bytes??
		printDebug("socket returned tag: \(tag)")
	}

	public func socket(_: MQTTSocketProtocol, didRead data: Data, withTag tag: Int) {
		let etag = MQTTReadTag(rawValue: tag)!
		var bytes = [UInt8]([0])
		switch etag {
		case MQTTReadTag.header:
			data.copyBytes(to: &bytes, count: 1)
			self.reader!.headerReady(bytes[0])
		case MQTTReadTag.length:
			data.copyBytes(to: &bytes, count: 1)
			self.reader!.lengthReady(bytes[0])
		case MQTTReadTag.payload:
			self.reader!.payloadReady(data)
		}
	}

	public func socketDidDisconnect(_ socket: MQTTSocketProtocol, withError err: Error?) {
		if err != nil { x.log(.error).err(err.unsafelyUnwrapped).send("some error") }
		// Clean up
		socket.setDelegate(nil, delegateQueue: nil)
		self.connState = .disconnected

		self.delegate?.didDisconnect(self, withError: err)
		self.didDisconnect(self, err)

		guard self.is_internal_disconnected else {
			return
		}

		guard self.autoReconnect else {
			return
		}

		if self.reconnectTimeInterval == 0 {
			self.reconnectTimeInterval = self.autoReconnectTimeInterval
		}

		// Start reconnector once socket error occurred
		printInfo("Try reconnect to server after \(self.reconnectTimeInterval)s")
		self.autoReconnTimer = MQTTTimer.after(Double(self.reconnectTimeInterval), name: "autoReconnTimer") { [weak self] in
			guard let self else { return }
			if self.reconnectTimeInterval < self.maxAutoReconnectTimeInterval {
				self.reconnectTimeInterval *= 2
			} else {
				self.reconnectTimeInterval = self.maxAutoReconnectTimeInterval
			}
			_ = self.connect()
		}
	}
}

// MARK: - MQTTReaderDelegate

extension MQTT5: MQTTReaderDelegate {
	func didReceive(_: MQTTReader, disconnect: FrameDisconnect) {
		self.delegate?.didReceiveDisconnect(self, reasonCode: disconnect.receiveReasonCode!)
		self.didDisconnectReasonCode(self, disconnect.receiveReasonCode!)
	}

	func didReceive(_: MQTTReader, auth: FrameAuth) {
		self.delegate?.didReceiveAuth(self, reasonCode: auth.receiveReasonCode!)
		self.didAuthReasonCode(self, auth.receiveReasonCode!)
	}

	func didReceive(_: MQTTReader, connack: FrameConnAck) {
		printDebug("RECV: \(connack)")

		if connack.reasonCode == .success {
			// Disable auto-reconnect

			self.reconnectTimeInterval = 0
			self.autoReconnTimer = nil
			self.is_internal_disconnected = false

			// Start keepalive timer

			let interval = Double(keepAlive <= 0 ? 60 : self.keepAlive)

			self.aliveTimer = MQTTTimer.every(interval, name: "aliveTimer") { [weak self] in
				guard let self else { return }
				self.delegateQueue.async {
					guard self.connState == .connected else {
						self.aliveTimer = nil
						return
					}
					self.ping()
				}
			}

			// recover session if enable

			if self.cleanSession {
				self.deliver.cleanAll()
			} else {
				if let storage = MQTTStorage(by: clientID) {
					self.deliver.recoverSessionBy(storage)
				} else {
					printWarning("Localstorage initial failed for key: \(self.clientID)")
				}
			}

			self.connState = .connected

		} else {
			self.connState = .disconnected
			self.internal_disconnect()
		}

		if let reasonCode = connack.reasonCode {
			self.delegate?.didConnect(self, ack: reasonCode, data: connack.connackProperties ?? nil)
			self.didConnectAck(self, reasonCode, connack.connackProperties ?? nil)
		} else {
			printWarning("No reasonCode for connack.")
		}
	}

	func didReceive(_: MQTTReader, publish: FramePublish) {
		printDebug("RECV: \(publish)")

		let message = MQTT5Message(topic: publish.mqtt5Topic, payload: publish.payload5(), qos: publish.qos, retained: publish.retained)

		message.duplicated = publish.dup

		printInfo("Received message: \(message), sending to delegate [\(self.delegate.debugDescription)]")
		self.delegate?.didReceive(self, message: message, id: publish.msgid, data: publish.publishRecProperties ?? nil)
		self.didReceiveMessage(self, message, publish.msgid, publish.publishRecProperties ?? nil)

		if message.qos == .qos1 {
			self.puback(FrameType.puback, msgid: publish.msgid)
		} else if message.qos == .qos2 {
			self.puback(FrameType.pubrec, msgid: publish.msgid)
		}
	}

	func didReceive(_: MQTTReader, puback: FramePubAck) {
		printDebug("RECV: \(puback)")

		self.deliver.ack(by: puback)

		self.delegate?.didPublish(self, ack: puback.msgid, data: puback.pubAckProperties ?? nil)
		self.didPublishAck(self, puback.msgid, puback.pubAckProperties ?? nil)
	}

	func didReceive(_: MQTTReader, pubrec: FramePubRec) {
		printDebug("RECV: \(pubrec)")

		self.deliver.ack(by: pubrec)

		self.delegate?.didPublish(self, rec: pubrec.msgid, data: pubrec.pubRecProperties ?? nil)
		self.didPublishRec(self, pubrec.msgid, pubrec.pubRecProperties ?? nil)
	}

	func didReceive(_: MQTTReader, pubrel: FramePubRel) {
		printDebug("RECV: \(pubrel)")

		self.puback(FrameType.pubcomp, msgid: pubrel.msgid)
	}

	func didReceive(_: MQTTReader, pubcomp: FramePubComp) {
		printDebug("RECV: \(pubcomp)")

		self.deliver.ack(by: pubcomp)

		self.delegate?.didPublish(self, complete: pubcomp.msgid, data: pubcomp.pubCompProperties ?? nil)
		self.didCompletePublish(self, pubcomp.msgid, pubcomp.pubCompProperties ?? nil)
	}

	func didReceive(_: MQTTReader, suback: FrameSubAck) {
		printDebug("RECV: \(suback)")
		guard let topicsAndQos = subscriptionsWaitingAck.removeValue(forKey: suback.msgid) else {
			printWarning("UNEXPECT SUBACK Received: \(suback)")
			return
		}

		guard topicsAndQos.count == suback.grantedQos.count else {
			printWarning("UNEXPECT SUBACK Recivied: \(suback)")
			return
		}

		let success: NSMutableDictionary = .init()
		var failed = [String]()
		for (idx, subscriptionList) in topicsAndQos.enumerated() {
			if suback.grantedQos[idx] != .FAILURE {
				self.subscriptions[subscriptionList.topic] = suback.grantedQos[idx]
				success[subscriptionList.topic] = suback.grantedQos[idx].rawValue
			} else {
				failed.append(subscriptionList.topic)
			}
		}

		self.delegate?.didSubscribe(self, topics: success, failed: failed, data: suback.subAckProperties ?? nil)
		self.didSubscribeTopics(self, success, failed, suback.subAckProperties ?? nil)
	}

	func didReceive(_: MQTTReader, unsuback: FrameUnsubAck) {
		printDebug("RECV: \(unsuback)")

		guard let topics = unsubscriptionsWaitingAck.removeValue(forKey: unsuback.msgid) else {
			printWarning("UNEXPECT UNSUBACK Received: \(unsuback.msgid)")
			return
		}
		// Remove local subscription
		var removeTopics: [String] = []
		for t in topics {
			removeTopics.append(t.topic)
			self.subscriptions.removeValue(forKey: t.topic)
		}

		self.delegate?.didUnsubscribe(self, topics: removeTopics, data: unsuback.unSubAckProperties ?? nil)
		self.didUnsubscribeTopics(self, removeTopics, unsuback.unSubAckProperties ?? nil)
	}

	func didReceive(_: MQTTReader, pingresp: FramePingResp) {
		printDebug("RECV: \(pingresp)")

		self.delegate?.didReceivePong(self)
		self.didReceivePong(self)
	}
}
