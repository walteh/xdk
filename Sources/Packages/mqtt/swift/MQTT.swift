////
////  MQTT.swift
////  MQTT
////
////  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
////  Copyright (c) 2015 emqx.io. All rights reserved.
////

import Foundation

@objc public enum MQTTConnAck: UInt8, CustomStringConvertible {
	case accept = 0
	case unacceptableProtocolVersion
	case identifierRejected
	case serverUnavailable
	case badUsernameOrPassword
	case notAuthorized
	case reserved

	public var description: String {
		switch self {
		case .accept: return "accept"
		case .unacceptableProtocolVersion: return "unacceptableProtocolVersion"
		case .identifierRejected: return "identifierRejected"
		case .serverUnavailable: return "serverUnavailable"
		case .badUsernameOrPassword: return "badUsernameOrPassword"
		case .notAuthorized: return "notAuthorized"
		case .reserved: return "reserved"
		}
	}
}

//
///// MQTT Delegate
// @objc public protocol MQTTDelegate {
//
//    ///
//    func mqtt(_ mqtt: MQTT, didConnectAck ack: MQTTConnAck)
//
//    ///
//    func mqtt(_ mqtt: MQTT, didPublishMessage message: MQTTMessage, id: UInt16)
//
//    ///
//    func mqtt(_ mqtt: MQTT, didPublishAck id: UInt16)
//
//    ///
//    func mqtt(_ mqtt: MQTT, didReceiveMessage message: MQTTMessage, id: UInt16 )
//
//    ///
//    func mqtt(_ mqtt: MQTT, didSubscribeTopics success: NSDictionary, failed: [String])
//
//    ///
//    func mqtt(_ mqtt: MQTT, didUnsubscribeTopics topics: [String])
//
//    ///
//    func mqttDidPing(_ mqtt: MQTT)
//
//    ///
//    func mqttDidReceivePong(_ mqtt: MQTT)
//
//    ///
//    func mqttDidDisconnect(_ mqtt: MQTT, withError err: Error?)
//
//    /// Manually validate SSL/TLS server certificate.
//    ///
//    /// This method will be called if enable  `allowUntrustCACertificate`
//    @objc optional func mqtt(_ mqtt: MQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void)
//
//    ///
//    @objc optional func mqtt(_ mqtt: MQTT, didPublishComplete id: UInt16)
//
//    ///
//    @objc optional func mqtt(_ mqtt: MQTT, didStateChangeTo state: MQTTConnState)
// }
//
/// **
// * Blueprint of the MQTT Client
// */
// protocol MQTTClient {
//
//    /* Basic Properties */
//
//    var host: String { get set }
//    var port: UInt16 { get set }
//    var clientID: String { get }
//    var username: String? {get set}
//    var password: String? {get set}
//    var cleanSession: Bool {get set}
//    var keepAlive: UInt16 {get set}
//    var willMessage: MQTTMessage? {get set}
//
//    /* Basic Properties */
//
//    /* CONNNEC/DISCONNECT */
//
//    func connect() -> Bool
//    func connect(timeout:TimeInterval) -> Bool
//    func disconnect()
//    func ping()
//
//    /* CONNNEC/DISCONNECT */
//
//    /* PUBLISH/SUBSCRIBE */
//
//    func subscribe(_ topic: String, qos: MQTTQoS)
//    func subscribe(_ topics: [(String, MQTTQoS)])
//
//    func unsubscribe(_ topic: String)
//    func unsubscribe(_ topics: [String])
//
//    func publish(_ topic: String, withString string: String, qos: MQTTQoS, retained: Bool) -> Int
//    func publish(_ message: MQTTMessage) -> Int
//
//    /* PUBLISH/SUBSCRIBE */
// }
//
//
///// MQTT Client
/////
///// - Note: GCDAsyncSocket need delegate to extend NSObject
// public class MQTT: NSObject, MQTTClient {
//
//    public weak var delegate: MQTTDelegate?
//
//    private var version = "3.1.1"
//
//    public var host = "localhost"
//
//    public var port: UInt16 = 1883
//
//    public var clientID: String
//
//    public var username: String?
//
//    public var password: String?
//
//    /// Clean Session flag. Default is true
//    ///
//    /// - TODO: What's behavior each Clean Session flags???
//    public var cleanSession = true
//
//    /// Setup a **Last Will Message** to client before connecting to broker
//    public var willMessage: MQTTMessage?
//
//    /// Enable backgounding socket if running on iOS platform. Default is true
//    ///
//    /// - Note:
//    public var backgroundOnSocket: Bool {
//        get { return (self.socket as? MQTTSocket)?.backgroundOnSocket ?? true }
//        set { (self.socket as? MQTTSocket)?.backgroundOnSocket = newValue }
//    }
//
//    /// Delegate Executed queue. Default is `DispatchQueue.main`
//    ///
//    /// The delegate/closure callback function will be committed asynchronously to it
//    public var delegateQueue = DispatchQueue.main
//
//    public var connState = MQTTConnState.disconnected {
//        didSet {
//            __delegate_queue {
//                self.delegate?.mqtt?(self, didStateChangeTo: self.connState)
//                self.didChangeState(self, self.connState)
//            }
//        }
//    }
//
//    // deliver
//    private var deliver = MQTTDeliver()
//
//    /// Re-deliver the un-acked messages
//    public var deliverTimeout: Double {
//        get { return deliver.retryTimeInterval }
//        set { deliver.retryTimeInterval = newValue }
//    }
//
//    /// Message queue size. default 1000
//    ///
//    /// The new publishing messages of Qos1/Qos2 will be drop, if the queue is full
//    public var messageQueueSize: UInt {
//        get { return deliver.mqueueSize }
//        set { deliver.mqueueSize = newValue }
//    }
//
//    /// In-flight window size. default 10
//    public var inflightWindowSize: UInt {
//        get { return deliver.inflightWindowSize }
//        set { deliver.inflightWindowSize = newValue }
//    }
//
//    /// Keep alive time interval
//    public var keepAlive: UInt16 = 60
//    private var aliveTimer: MQTTTimer?
//
//    /// Enable auto-reconnect mechanism
//    public var autoReconnect = false
//
//    /// Reconnect time interval
//    ///
//    /// - note: This value will be increased with `autoReconnectTimeInterval *= 2`
//    ///         if reconnect failed
//    public var autoReconnectTimeInterval: UInt16 = 1 // starts from 1 second
//
//    /// Maximum auto reconnect time interval
//    ///
//    /// The timer starts from `autoReconnectTimeInterval` second and grows exponentially until this value
//    /// After that, it uses this value for subsequent requests.
//    public var maxAutoReconnectTimeInterval: UInt16 = 128 // 128 seconds
//
//    private var reconnectTimeInterval: UInt16 = 0
//
//    private var autoReconnTimer: MQTTTimer?
//    private var is_internal_disconnected = false
//
//    /// Console log level
//    public var logLevel: MQTTLoggerLevel {
//        get {
//            return MQTTLogger.logger.minLevel
//        }
//        set {
//            MQTTLogger.logger.minLevel = newValue
//        }
//    }
//
//    /// Enable SSL connection
//    public var enableSSL: Bool {
//        get { return self.socket.enableSSL }
//        set { socket.enableSSL = newValue }
//    }
//
//    ///
//    public var sslSettings: [String: NSObject]? {
//        get { return (self.socket as? MQTTSocket)?.sslSettings ?? nil }
//        set { (self.socket as? MQTTSocket)?.sslSettings = newValue }
//    }
//
//    /// Allow self-signed ca certificate.
//    ///
//    /// Default is false
//    public var allowUntrustCACertificate: Bool {
//        get { return (self.socket as? MQTTSocket)?.allowUntrustCACertificate ?? false }
//        set { (self.socket as? MQTTSocket)?.allowUntrustCACertificate = newValue }
//    }
//
//    /// The subscribed topics in current communication
//    public var subscriptions: [String: MQTTQoS] = [:]
//
//    fileprivate var subscriptionsWaitingAck: [UInt16: [(String, MQTTQoS)]] = [:]
//    fileprivate var unsubscriptionsWaitingAck: [UInt16: [String]] = [:]
//
//
//    /// Sending messages
//    fileprivate var sendingMessages: [UInt16: MQTTMessage] = [:]
//
//    /// message id counter
//    private var _msgid: UInt16 = 0
//    fileprivate var socket: MQTTSocketProtocol
//    fileprivate var reader: MQTTReader?
//
//    // Closures
//    public var didConnectAck: (MQTT, MQTTConnAck) -> Void = { _, _ in }
//    public var didPublishMessage: (MQTT, MQTTMessage, UInt16) -> Void = { _, _, _ in }
//    public var didPublishAck: (MQTT, UInt16) -> Void = { _, _ in }
//    public var didReceiveMessage: (MQTT, MQTTMessage, UInt16) -> Void = { _, _, _ in }
//    public var didSubscribeTopics: (MQTT, NSDictionary, [String]) -> Void = { _, _, _  in }
//    public var didUnsubscribeTopics: (MQTT, [String]) -> Void = { _, _ in }
//    public var didPing: (MQTT) -> Void = { _ in }
//    public var didReceivePong: (MQTT) -> Void = { _ in }
//    public var didDisconnect: (MQTT, Error?) -> Void = { _, _ in }
//    public var didReceiveTrust: (MQTT, SecTrust, @escaping (Bool) -> Swift.Void) -> Void = { _, _, _ in }
//    public var didCompletePublish: (MQTT, UInt16) -> Void = { _, _ in }
//    public var didChangeState: (MQTT, MQTTConnState) -> Void = { _, _ in }
//
//    /// Initial client object
//    ///
//    /// - Parameters:
//    ///   - clientID: Client Identifier
//    ///   - host: The MQTT broker host domain or IP address. Default is "localhost"
//    ///   - port: The MQTT service port of host. Default is 1883
//    public init(clientID: String, host: String = "localhost", port: UInt16 = 1883, socket: MQTTSocketProtocol = MQTTSocket()) {
//        self.clientID = clientID
//        self.host = host
//        self.port = port
//        self.socket = socket
//        super.init()
//        deliver.delegate = self
//        if let storage = MQTTStorage() {
//            storage.setMQTTVersion("3.1.1")
//        } else {
//            printWarning("Localstorage initial failed for key: \(clientID)")
//        }
//    }
//
//    deinit {
//        aliveTimer?.suspend()
//        autoReconnTimer?.suspend()
//
//        socket.setDelegate(nil, delegateQueue: nil)
//        socket.disconnect()
//    }
//
//    fileprivate func send(_ frame: Frame, tag: Int = 0) {
//        printDebug("SEND: \(frame)")
//        let data = frame.bytes(version: version)
//        socket.write(Data(bytes: data, count: data.count), withTimeout: 5, tag: tag)
//    }
//
//    fileprivate func sendConnectFrame() {
//
//        var connect = FrameConnect(clientID: clientID)
//        connect.keepAlive = keepAlive
//        connect.username = username
//        connect.password = password
//        connect.willMsg = willMessage
//        connect.cleansess = cleanSession
//
//        send(connect)
//        reader!.start()
//    }
//
//    fileprivate func nextMessageID() -> UInt16 {
//        if _msgid == UInt16.max {
//            _msgid = 0
//        }
//        _msgid += 1
//        return _msgid
//    }
//
//    fileprivate func puback(_ type: FrameType, msgid: UInt16) {
//        switch type {
//        case .puback:
//            send(FramePubAck(msgid: msgid))
//        case .pubrec:
//            send(FramePubRec(msgid: msgid))
//        case .pubcomp:
//            send(FramePubComp(msgid: msgid))
//        default: return
//        }
//    }
//
//    /// Connect to MQTT broker
//    ///
//    /// - Returns:
//    ///   - Bool: It indicates whether successfully calling socket connect function.
//    ///           Not yet established correct MQTT session
//    public func connect() -> Bool {
//        return connect(timeout: -1)
//    }
//
//    /// Connect to MQTT broker
//    /// - Parameters:
//    ///   - timeout: Connect timeout
//    /// - Returns:
//    ///   - Bool: It indicates whether successfully calling socket connect function.
//    ///           Not yet established correct MQTT session
//    public func connect(timeout: TimeInterval) -> Bool {
//        socket.setDelegate(self, delegateQueue: delegateQueue)
//        reader = MQTTReader(socket: socket, delegate: self)
//        do {
//            if timeout > 0 {
//                try socket.connect(toHost: self.host, onPort: self.port, withTimeout: timeout)
//            } else {
//                try socket.connect(toHost: self.host, onPort: self.port)
//            }
//
//            delegateQueue.async { [weak self] in
//                guard let self = self else { return }
//                self.connState = .connecting
//            }
//
//            return true
//        } catch let error as NSError {
//            printError("socket connect error: \(error.description)")
//            return false
//        }
//    }
//
//    /// Send a DISCONNECT packet to the broker then close the connection
//    ///
//    /// - Note: Only can be called from outside.
//    ///         If you want to disconnect from inside framework, call internal_disconnect()
//    ///         disconnect expectedly
//    public func disconnect() {
//        internal_disconnect()
//        is_internal_disconnected = false
//    }
//
//    /// Disconnect unexpectedly
//    func internal_disconnect() {
//        is_internal_disconnected = true
//        send(FrameDisconnect(), tag: -0xE0)
//        socket.disconnect()
//    }
//
//    /// Send a PING request to broker
//    public func ping() {
//        printDebug("ping")
//        send(FramePingReq(), tag: -0xC0)
//
//        __delegate_queue {
//            self.delegate?.mqttDidPing(self)
//            self.didPing(self)
//        }
//    }
//
//    /// Publish a message to broker
//    ///
//    /// - Parameters:
//    ///    - topic: Topic Name. It can not contain '#', '+' wildcards
//    ///    - string: Payload string
//    ///    - qos: Qos. Default is Qos1
//    ///    - retained: Retained flag. Mark this message is a retained message. default is false
//    /// - Returns:
//    ///     - 0 will be returned, if the message's qos is qos0
//    ///     - 1-65535 will be returned, if the messages's qos is qos1/qos2
//    ///     - -1 will be returned, if the messages queue is full
//    @discardableResult
//    public func publish(_ topic: String, withString string: String, qos: MQTTQoS = .qos1, retained: Bool = false) -> Int {
//        let message = MQTTMessage(topic: topic, string: string, qos: qos, retained: retained)
//        return publish(message)
//    }
//
//    /// Publish a message to broker
//    ///
//    /// - Parameters:
//    ///   - message: Message
//    @discardableResult
//    public func publish(_ message: MQTTMessage) -> Int {
//        let msgid: UInt16
//
//        if message.qos == .qos0 {
//            msgid = 0
//        } else {
//            msgid = nextMessageID()
//        }
//
//        var frame = FramePublish(topic: message.topic,
//                                 payload: message.payload,
//                                 qos: message.qos,
//                                 msgid: msgid)
//
//        frame.retained = message.retained
//
//        delegateQueue.async {
//            self.sendingMessages[msgid] = message
//        }
//
//        // Push frame to deliver message queue
//        guard deliver.add(frame) else {
//            delegateQueue.async {
//                self.sendingMessages.removeValue(forKey: msgid)
//            }
//            return -1
//        }
//
//        return Int(msgid)
//    }
//
//    /// Subscribe a `<Topic Name>/<Topic Filter>`
//    ///
//    /// - Parameters:
//    ///   - topic: Topic Name or Topic Filter
//    ///   - qos: Qos. Default is qos1
//    public func subscribe(_ topic: String, qos: MQTTQoS = .qos1) {
//        return subscribe([(topic, qos)])
//    }
//
//    /// Subscribe a lists of topics
//    ///
//    /// - Parameters:
//    ///   - topics: A list of tuples presented by `(<Topic Names>/<Topic Filters>, Qos)`
//    public func subscribe(_ topics: [(String, MQTTQoS)]) {
//        let msgid = nextMessageID()
//        let frame = FrameSubscribe(msgid: msgid, topics: topics)
//        send(frame, tag: Int(msgid))
//        subscriptionsWaitingAck[msgid] = topics
//    }
//
//    /// Unsubscribe a Topic
//    ///
//    /// - Parameters:
//    ///   - topic: A Topic Name or Topic Filter
//    public func unsubscribe(_ topic: String) {
//        return unsubscribe([topic])
//    }
//
//    /// Unsubscribe a list of topics
//    ///
//    /// - Parameters:
//    ///   - topics: A list of `<Topic Names>/<Topic Filters>`
//    public func unsubscribe(_ topics: [String]) {
//        let msgid = nextMessageID()
//        let frame = FrameUnsubscribe(msgid: msgid, topics: topics)
//        unsubscriptionsWaitingAck[msgid] = topics
//        send(frame, tag: Int(msgid))
//    }
// }
//
//// MARK: MQTTDeliverProtocol
// extension MQTT: MQTTDeliverProtocol {
//
//    func deliver(_ deliver: MQTTDeliver, wantToSend frame: Frame) {
//        if let publish = frame as? FramePublish {
//            let msgid = publish.msgid
//            guard let message = sendingMessages[msgid] else {
//                printError("Want send \(frame), but not found in MQTT cache")
//                return
//            }
//
//            send(publish, tag: Int(msgid))
//
//
//            self.delegate?.mqtt(self, didPublishMessage: message, id: msgid)
//            self.didPublishMessage(self, message, msgid)
//
//        } else if let pubrel = frame as? FramePubRel {
//            // -- Send PUBREL
//            send(pubrel, tag: Int(pubrel.msgid))
//        }
//    }
// }
//
// extension MQTT {
//
//    func __delegate_queue(_ fun: @escaping () -> Void) {
//        delegateQueue.async { [weak self] in
//            guard let _ = self else { return }
//            fun()
//        }
//    }
// }
//
//// MARK: - MQTTSocketDelegate
// extension MQTT: MQTTSocketDelegate {
//
//    public func socketConnected(_ socket: MQTTSocketProtocol) {
//        sendConnectFrame()
//    }
//
//    public func socket(_ socket: MQTTSocketProtocol,
//                       didReceive trust: SecTrust,
//                       completionHandler: @escaping (Bool) -> Swift.Void) {
//
//        printDebug("Call the SSL/TLS manually validating function")
//
//        delegate?.mqtt?(self, didReceive: trust, completionHandler: completionHandler)
//        didReceiveTrust(self, trust, completionHandler)
//    }
//
//    // ?
//    public func socketDidSecure() {
//        printDebug("Socket has successfully completed SSL/TLS negotiation")
//        sendConnectFrame()
//    }
//
//    public func socket(_ socket: MQTTSocketProtocol, didWriteDataWithTag tag: Int) {
//        // XXX: How to print writed bytes??
//    }
//
//    public func socket(_ socket: MQTTSocketProtocol, didRead data: Data, withTag tag: Int) {
//        let etag = MQTTReadTag(rawValue: tag)!
//        var bytes = [UInt8]([0])
//        switch etag {
//        case MQTTReadTag.header:
//            data.copyBytes(to: &bytes, count: 1)
//            reader!.headerReady(bytes[0])
//        case MQTTReadTag.length:
//            data.copyBytes(to: &bytes, count: 1)
//            reader!.lengthReady(bytes[0])
//        case MQTTReadTag.payload:
//            reader!.payloadReady(data)
//        }
//    }
//
//    public func socketDidDisconnect(_ socket: MQTTSocketProtocol, withError err: Error?) {
//        // Clean up
//        socket.setDelegate(nil, delegateQueue: nil)
//        connState = .disconnected
//        delegate?.mqttDidDisconnect(self, withError: err)
//        didDisconnect(self, err)
//
//        guard is_internal_disconnected else {
//            return
//        }
//
//        guard autoReconnect else {
//            return
//        }
//
//        if reconnectTimeInterval == 0 {
//            reconnectTimeInterval = autoReconnectTimeInterval
//        }
//
//        // Start reconnector once socket error occurred
//        printInfo("Try reconnect to server after \(reconnectTimeInterval)s")
//        autoReconnTimer = MQTTTimer.after(Double(reconnectTimeInterval), name: "autoReconnTimer", { [weak self] in
//            guard let self = self else { return }
//            if self.reconnectTimeInterval < self.maxAutoReconnectTimeInterval {
//                self.reconnectTimeInterval *= 2
//            } else {
//                self.reconnectTimeInterval = self.maxAutoReconnectTimeInterval
//            }
//            _ = self.connect()
//        })
//    }
// }
//
//// MARK: - MQTTReaderDelegate
// extension MQTT: MQTTReaderDelegate {
//
//    func didReceive(_ reader: MQTTReader, connack: FrameConnAck) {
//        printDebug("RECV: \(connack)")
//
//        if connack.returnCode == .accept {
//
//            // Disable auto-reconnect
//
//            reconnectTimeInterval = 0
//            autoReconnTimer = nil
//            is_internal_disconnected = false
//
//            // Start keepalive timer
//
//            let interval = Double(keepAlive <= 0 ? 60: keepAlive)
//
//            aliveTimer = MQTTTimer.every(interval, name: "aliveTimer") { [weak self] in
//                guard let self = self else { return }
//                self.delegateQueue.async {
//                    guard self.connState == .connected else {
//                        self.aliveTimer = nil
//                        return
//                    }
//                    self.ping()
//                }
//            }
//
//            // recover session if enable
//
//            if cleanSession {
//                deliver.cleanAll()
//            } else {
//                if let storage = MQTTStorage(by: clientID) {
//                    deliver.recoverSessionBy(storage)
//                } else {
//                    printWarning("Localstorage initial failed for key: \(clientID)")
//                }
//            }
//
//            connState = .connected
//
//        } else {
//            connState = .disconnected
//            internal_disconnect()
//        }
//
//        if let returnCode = connack.returnCode {
//            delegate?.mqtt(self, didConnectAck: returnCode)
//            didConnectAck(self, returnCode)
//        }
//        else {
//            printWarning("No return code for connack.")
//        }
//    }
//
//    func didReceive(_ reader: MQTTReader, publish: FramePublish) {
//        printDebug("RECV: \(publish)")
//
//        let message = MQTTMessage(topic: publish.topic, payload: publish.payload(), qos: publish.qos, retained: publish.retained)
//
//        message.duplicated = publish.dup
//
//        printInfo("Received message: \(message)")
//        delegate?.mqtt(self, didReceiveMessage: message, id: publish.msgid)
//        didReceiveMessage(self, message, publish.msgid)
//
//        if message.qos == .qos1 {
//            puback(FrameType.puback, msgid: publish.msgid)
//        } else if message.qos == .qos2 {
//            puback(FrameType.pubrec, msgid: publish.msgid)
//        }
//    }
//
//    func didReceive(_ reader: MQTTReader, puback: FramePubAck) {
//        printDebug("RECV: \(puback)")
//
//        deliver.ack(by: puback)
//
//        delegate?.mqtt(self, didPublishAck: puback.msgid)
//        didPublishAck(self, puback.msgid)
//    }
//
//    func didReceive(_ reader: MQTTReader, pubrec: FramePubRec) {
//        printDebug("RECV: \(pubrec)")
//
//        deliver.ack(by: pubrec)
//    }
//
//    func didReceive(_ reader: MQTTReader, pubrel: FramePubRel) {
//        printDebug("RECV: \(pubrel)")
//
//        puback(FrameType.pubcomp, msgid: pubrel.msgid)
//    }
//
//    func didReceive(_ reader: MQTTReader, pubcomp: FramePubComp) {
//        printDebug("RECV: \(pubcomp)")
//
//        deliver.ack(by: pubcomp)
//
//        delegate?.mqtt?(self, didPublishComplete: pubcomp.msgid)
//        didCompletePublish(self, pubcomp.msgid)
//    }
//
//    func didReceive(_ reader: MQTTReader, suback: FrameSubAck) {
//        printDebug("RECV: \(suback)")
//        guard let topicsAndQos = subscriptionsWaitingAck.removeValue(forKey: suback.msgid) else {
//            printWarning("UNEXPECT SUBACK Received: \(suback)")
//            return
//        }
//
//        guard topicsAndQos.count == suback.grantedQos.count else {
//            printWarning("UNEXPECT SUBACK Recivied: \(suback)")
//            return
//        }
//
//        let success: NSMutableDictionary = NSMutableDictionary()
//        var failed = [String]()
//        for (idx,(topic, _)) in topicsAndQos.enumerated() {
//            if suback.grantedQos[idx] != .FAILURE {
//                subscriptions[topic] = suback.grantedQos[idx]
//                success[topic] = suback.grantedQos[idx].rawValue
//            } else {
//                failed.append(topic)
//            }
//        }
//
//        delegate?.mqtt(self, didSubscribeTopics: success, failed: failed)
//        didSubscribeTopics(self, success, failed)
//    }
//
//    func didReceive(_ reader: MQTTReader, unsuback: FrameUnsubAck) {
//        printDebug("RECV: \(unsuback)")
//
//        guard let topics = unsubscriptionsWaitingAck.removeValue(forKey: unsuback.msgid) else {
//            printWarning("UNEXPECT UNSUBACK Received: \(unsuback.msgid)")
//            return
//        }
//        // Remove local subscription
//        for t in topics {
//            subscriptions.removeValue(forKey: t)
//        }
//        delegate?.mqtt(self, didUnsubscribeTopics: topics)
//        didUnsubscribeTopics(self, topics)
//    }
//
//    func didReceive(_ reader: MQTTReader, pingresp: FramePingResp) {
//        printDebug("RECV: \(pingresp)")
//
//        delegate?.mqttDidReceivePong(self)
//        didReceivePong(self)
//    }
// }
