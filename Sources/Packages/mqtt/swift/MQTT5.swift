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
		get { return (socket as? MQTTSocket)?.backgroundOnSocket ?? true }
		set { (socket as? MQTTSocket)?.backgroundOnSocket = newValue }
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
		get { return deliver.retryTimeInterval }
		set { deliver.retryTimeInterval = newValue }
	}

	/// Message queue size. default 1000
	///
	/// The new publishing messages of Qos1/Qos2 will be drop, if the queue is full
	public var messageQueueSize: UInt {
		get { return deliver.mqueueSize }
		set { deliver.mqueueSize = newValue }
	}

	/// In-flight window size. default 10
	public var inflightWindowSize: UInt {
		get { return deliver.inflightWindowSize }
		set { deliver.inflightWindowSize = newValue }
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
		get { return socket.enableSSL }
		set { socket.enableSSL = newValue }
	}

	///
	public var sslSettings: [String: NSObject]? {
		get { return (socket as? MQTTSocket)?.sslSettings ?? nil }
		set { (socket as? MQTTSocket)?.sslSettings = newValue }
	}

	/// Allow self-signed ca certificate.
	///
	/// Default is false
	public var allowUntrustCACertificate: Bool {
		get { return (socket as? MQTTSocket)?.allowUntrustCACertificate ?? false }
		set { (socket as? MQTTSocket)?.allowUntrustCACertificate = newValue }
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
		deliver.delegate = self
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
		let data = frame.bytes(version: version)
		socket.write(Data(bytes: data, count: data.count), withTimeout: 5, tag: tag)
	}

	fileprivate func sendConnectFrame() {
		var connect = FrameConnect(clientID: clientID)
		connect.keepAlive = keepAlive
		connect.username = username
		connect.password = password
		connect.willMsg5 = willMessage
		connect.cleansess = cleanSession

		connect.connectProperties = connectProperties

		send(connect)
		reader!.start()
	}

	fileprivate func nextMessageID() -> UInt16 {
		if _msgid == UInt16.max {
			_msgid = 0
		}
		_msgid += 1
		return _msgid
	}

	fileprivate func puback(_ type: FrameType, msgid: UInt16) {
		switch type {
		case .puback:
			send(FramePubAck(msgid: msgid, reasonCode: MQTTPUBACKReasonCode.success))
		case .pubrec:
			send(FramePubRec(msgid: msgid, reasonCode: MQTTPUBRECReasonCode.success))
		case .pubcomp:
			send(FramePubComp(msgid: msgid, reasonCode: MQTTPUBCOMPReasonCode.success))
		default: return
		}
	}

	/// Connect to MQTT broker
	///
	/// - Returns:
	///   - Bool: It indicates whether successfully calling socket connect function.
	///           Not yet established correct MQTT session
	public func connect() -> Bool {
		return connect(timeout: -1)
	}

	/// Connect to MQTT broker
	/// - Parameters:
	///   - timeout: Connect timeout
	/// - Returns:
	///   - Bool: It indicates whether successfully calling socket connect function.
	///           Not yet established correct MQTT session
	public func connect(timeout: TimeInterval) -> Bool {
		socket.setDelegate(self, delegateQueue: delegateQueue)
		reader = MQTTReader(socket: socket, delegate: self)
		printDebug("connecting to socket @ \(host):\(port)")
		do {
			if timeout > 0 {
				try socket.connect(toHost: host, onPort: port, withTimeout: timeout)
			} else {
				try socket.connect(toHost: host, onPort: port)
			}

			printDebug("socket connected")

			delegateQueue.async { [weak self] in
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
		internal_disconnect()
		is_internal_disconnected = false
	}

	public func disconnect(reasonCode: MQTTDISCONNECTReasonCode, userProperties: [String: String]) {
		internal_disconnect_withProperties(reasonCode: reasonCode, userProperties: userProperties)
		is_internal_disconnected = false
	}

	/// Disconnect unexpectedly
	func internal_disconnect() {
		is_internal_disconnected = true
		send(FrameDisconnect(disconnectReasonCode: MQTTDISCONNECTReasonCode.normalDisconnection), tag: -0xE0)
		socket.disconnect()
	}

	func internal_disconnect_withProperties(reasonCode: MQTTDISCONNECTReasonCode, userProperties: [String: String]) {
		is_internal_disconnected = true
		var frameDisconnect = FrameDisconnect(disconnectReasonCode: reasonCode)
		frameDisconnect.userProperties = userProperties
		send(frameDisconnect, tag: -0xE0)
		socket.disconnect()
	}

	/// Send a PING request to broker
	public func ping() {
		printDebug("ping")
		send(FramePingReq(), tag: -0xC0)

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
		return publish(message: message, DUP: DUP, retained: retained, properties: properties)
	}

	/// Publish a message to broker
	///
	/// - Parameters:
	///   - message: Message
	///   - properties: Publish Properties
	@discardableResult
	public func publish(message: MQTT5Message, DUP: Bool = false, retained _: Bool = false, properties: MQTTPublishProperties) -> Int {
		let msgid: UInt16

		if message.qos == .qos0 {
			msgid = 0
		} else {
			msgid = nextMessageID()
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

		delegateQueue.async {
			self.sendingMessages[msgid] = message
		}

		// Push frame to deliver message queue
		guard deliver.add(frame) else {
			delegateQueue.async {
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
		return subscribe(topics: [filter])
	}

	/// Subscribe a lists of topics
	///
	/// - Parameters:
	///   - topics: A list of tuples presented by `(<Topic Names>/<Topic Filters>, Qos)`
	public func subscribe(topics: [MQTTSubscription]) {
		let msgid = nextMessageID()
		let frame = FrameSubscribe(msgid: msgid, subscriptionList: topics)
		send(frame, tag: Int(msgid))
		subscriptionsWaitingAck[msgid] = topics
	}

	/// Unsubscribe a Topic
	///
	/// - Parameters:
	///   - topic: A Topic Name or Topic Filter
	public func unsubscribe(topic: String) {
		let filter = MQTTSubscription(topic: topic)
		return unsubscribe(topics: [filter])
	}

	/// Unsubscribe a list of topics
	///
	/// - Parameters:
	///   - topics: A list of `<Topic Names>/<Topic Filters>`
	public func unsubscribe(topics: [MQTTSubscription]) {
		let msgid = nextMessageID()
		let frame = FrameUnsubscribe(msgid: msgid, topics: topics)
		unsubscriptionsWaitingAck[msgid] = topics
		send(frame, tag: Int(msgid))
	}

	///  Authentication exchange
	///
	///
	public func auth(reasonCode: MQTTAUTHReasonCode, authProperties: MQTTAuthProperties) {
		printDebug("auth")
		let frame = FrameAuth(reasonCode: reasonCode, authProperties: authProperties)

		send(frame)
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

			send(publish, tag: Int(msgid))

			delegate?.didPublish(self, message: message, id: msgid)
			didPublishMessage(self, message, msgid)

		} else if let pubrel = frame as? FramePubRel {
			// -- Send PUBREL
			send(pubrel, tag: Int(pubrel.msgid))
		}
	}
}

extension MQTT5 {
	func __delegate_queue(_ fun: @escaping () -> Void) {
		delegateQueue.async { [weak self] in
			guard let _ = self else { return }
			fun()
		}
	}
}

// MARK: - MQTTSocketDelegate

extension MQTT5: MQTTSocketDelegate {
	public func socketConnected(_: MQTTSocketProtocol) {
		printDebug("socketConnected")
		sendConnectFrame()
	}

	public func socket(_: MQTTSocketProtocol,
	                   didReceive trust: SecTrust,
	                   completionHandler: @escaping (Bool) -> Swift.Void)
	{
		printDebug("Call the SSL/TLS manually validating function")
		delegate?.didReceive(self, trust: trust, completionHandler: completionHandler)
		didReceiveTrust(self, trust, completionHandler)
	}

	// ?
	public func socketDidSecure() {
		printDebug("Socket has successfully completed SSL/TLS negotiation")
		sendConnectFrame()
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
			reader!.headerReady(bytes[0])
		case MQTTReadTag.length:
			data.copyBytes(to: &bytes, count: 1)
			reader!.lengthReady(bytes[0])
		case MQTTReadTag.payload:
			reader!.payloadReady(data)
		}
	}

	public func socketDidDisconnect(_ socket: MQTTSocketProtocol, withError err: Error?) {
		if err != nil { x.error(err.unsafelyUnwrapped) }
		// Clean up
		socket.setDelegate(nil, delegateQueue: nil)
		connState = .disconnected

		delegate?.didDisconnect(self, withError: err)
		didDisconnect(self, err)

		guard is_internal_disconnected else {
			return
		}

		guard autoReconnect else {
			return
		}

		if reconnectTimeInterval == 0 {
			reconnectTimeInterval = autoReconnectTimeInterval
		}

		// Start reconnector once socket error occurred
		printInfo("Try reconnect to server after \(reconnectTimeInterval)s")
		autoReconnTimer = MQTTTimer.after(Double(reconnectTimeInterval), name: "autoReconnTimer") { [weak self] in
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
		delegate?.didReceiveDisconnect(self, reasonCode: disconnect.receiveReasonCode!)
		didDisconnectReasonCode(self, disconnect.receiveReasonCode!)
	}

	func didReceive(_: MQTTReader, auth: FrameAuth) {
		delegate?.didReceiveAuth(self, reasonCode: auth.receiveReasonCode!)
		didAuthReasonCode(self, auth.receiveReasonCode!)
	}

	func didReceive(_: MQTTReader, connack: FrameConnAck) {
		printDebug("RECV: \(connack)")

		if connack.reasonCode == .success {
			// Disable auto-reconnect

			reconnectTimeInterval = 0
			autoReconnTimer = nil
			is_internal_disconnected = false

			// Start keepalive timer

			let interval = Double(keepAlive <= 0 ? 60 : keepAlive)

			aliveTimer = MQTTTimer.every(interval, name: "aliveTimer") { [weak self] in
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

			if cleanSession {
				deliver.cleanAll()
			} else {
				if let storage = MQTTStorage(by: clientID) {
					deliver.recoverSessionBy(storage)
				} else {
					printWarning("Localstorage initial failed for key: \(clientID)")
				}
			}

			connState = .connected

		} else {
			connState = .disconnected
			internal_disconnect()
		}

		if let reasonCode = connack.reasonCode {
			delegate?.didConnect(self, ack: reasonCode, data: connack.connackProperties ?? nil)
			didConnectAck(self, reasonCode, connack.connackProperties ?? nil)
		} else {
			printWarning("No reasonCode for connack.")
		}
	}

	func didReceive(_: MQTTReader, publish: FramePublish) {
		printDebug("RECV: \(publish)")

		let message = MQTT5Message(topic: publish.mqtt5Topic, payload: publish.payload5(), qos: publish.qos, retained: publish.retained)

		message.duplicated = publish.dup

		printInfo("Received message: \(message), sending to delegate [\(delegate.debugDescription)]")
		delegate?.didReceive(self, message: message, id: publish.msgid, data: publish.publishRecProperties ?? nil)
		didReceiveMessage(self, message, publish.msgid, publish.publishRecProperties ?? nil)

		if message.qos == .qos1 {
			puback(FrameType.puback, msgid: publish.msgid)
		} else if message.qos == .qos2 {
			puback(FrameType.pubrec, msgid: publish.msgid)
		}
	}

	func didReceive(_: MQTTReader, puback: FramePubAck) {
		printDebug("RECV: \(puback)")

		deliver.ack(by: puback)

		delegate?.didPublish(self, ack: puback.msgid, data: puback.pubAckProperties ?? nil)
		didPublishAck(self, puback.msgid, puback.pubAckProperties ?? nil)
	}

	func didReceive(_: MQTTReader, pubrec: FramePubRec) {
		printDebug("RECV: \(pubrec)")

		deliver.ack(by: pubrec)

		delegate?.didPublish(self, rec: pubrec.msgid, data: pubrec.pubRecProperties ?? nil)
		didPublishRec(self, pubrec.msgid, pubrec.pubRecProperties ?? nil)
	}

	func didReceive(_: MQTTReader, pubrel: FramePubRel) {
		printDebug("RECV: \(pubrel)")

		puback(FrameType.pubcomp, msgid: pubrel.msgid)
	}

	func didReceive(_: MQTTReader, pubcomp: FramePubComp) {
		printDebug("RECV: \(pubcomp)")

		deliver.ack(by: pubcomp)

		delegate?.didPublish(self, complete: pubcomp.msgid, data: pubcomp.pubCompProperties ?? nil)
		didCompletePublish(self, pubcomp.msgid, pubcomp.pubCompProperties ?? nil)
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
				subscriptions[subscriptionList.topic] = suback.grantedQos[idx]
				success[subscriptionList.topic] = suback.grantedQos[idx].rawValue
			} else {
				failed.append(subscriptionList.topic)
			}
		}

		delegate?.didSubscribe(self, topics: success, failed: failed, data: suback.subAckProperties ?? nil)
		didSubscribeTopics(self, success, failed, suback.subAckProperties ?? nil)
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
			subscriptions.removeValue(forKey: t.topic)
		}

		delegate?.didUnsubscribe(self, topics: removeTopics, data: unsuback.unSubAckProperties ?? nil)
		didUnsubscribeTopics(self, removeTopics, unsuback.unSubAckProperties ?? nil)
	}

	func didReceive(_: MQTTReader, pingresp: FramePingResp) {
		printDebug("RECV: \(pingresp)")

		delegate?.didReceivePong(self)
		didReceivePong(self)
	}
}
