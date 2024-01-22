//
//  IOTCore.swift
//
//
//  Created by walter on 3/8/23.
//

import Foundation

import XDKSession
import XDKX

public extension mqtt {
	static func NewIOTCoreClient(host: String, session: some session.API, delegate: some mqtt.Delegate) -> MQTT5IOTCore {
		let res = MQTT5IOTCore(host: host, session: session, delegate: delegate)
		return res
	}
}

public class MQTT5IOTCore: MQTT5 {
	public static var queue = DispatchQueue(label: "mqtt.iot-core")

	init(host: String, session: some session.API, delegate: some mqtt.Delegate) {
		let sock = MQTTWebSocket(uri: "/mqtt")
		sock.enableSSL = true

		super.init(clientID: session.ID().description, host: host, port: 443, socket: sock)

		delegateQueue = MQTT5IOTCore.queue
		logLevel = .error
		autoReconnect = false
		username = session.ID().description
		self.delegate = delegate

		_ = connect()
	}
}

open class DefaultMQTT5Delegate: mqtt.Delegate {
	public init() {}

	let queue = DispatchQueue(label: "mqtt.delegate", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem)

	open func didConnect(_: mqtt.API, ack _: MQTTCONNACKReasonCode, data _: MQTTDecodeConnAck?) {}

	open func didPublish(_: mqtt.API, message _: MQTT5Message, id _: UInt16) {}

	open func didPublish(_: mqtt.API, ack _: UInt16, data _: MQTTDecodePubAck?) {}

	open func didPublish(_: mqtt.API, rec _: UInt16, data _: MQTTDecodePubRec?) {}

	open func didReceive(_: mqtt.API, message _: MQTT5Message, id _: UInt16, data _: MQTTDecodePublish?) {}

	open func didSubscribe(_: mqtt.API, topics _: NSDictionary, failed _: [String], data _: MQTTDecodeSubAck?) {}

	open func didUnsubscribe(_: mqtt.API, topics _: [String], data _: MQTTDecodeUnsubAck?) {}

	open func didReceiveDisconnect(_: mqtt.API, reasonCode _: MQTTDISCONNECTReasonCode) {}

	open func didReceiveAuth(_: mqtt.API, reasonCode _: MQTTAUTHReasonCode) {}

	open func didPing(_: mqtt.API) {}

	open func didReceivePong(_: mqtt.API) {}

	open func didDisconnect(_: mqtt.API, withError _: Error?) {}

	open func didReceive(_: mqtt.API, trust _: SecTrust, completionHandler: @escaping (Bool) -> Void) {
		completionHandler(true)
	}

	open func didPublish(_: mqtt.API, complete _: UInt16, data _: MQTTDecodePubComp?) {}

	open func didStateChange(_: mqtt.API, to _: MQTTConnState) {}
}
