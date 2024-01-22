//
//  File.swift
//
//
//  Created by walter on 3/10/23.
//

import Foundation

public enum mqtt {
	public typealias API = MQTTAPI
	public typealias Delegate = MQTT5Delegate
	public typealias DefaultDelegate = DefaultMQTT5Delegate
}

//
// public protocol MQTTAPI {
//	func publish(topic: String, message: Data, qos: MQTTQoS, retained: Bool)
//	func subscribe(topic: String, qos: MQTTQoS, process: Processor)
//	func wait() throws
// }

public protocol MQTTAPI {
//	var delegate: any MQTT5Delegate<Self.Type> { get set }

	/* Basic Properties */
	var host: String { get set }
	var port: UInt16 { get set }
	var clientID: String { get }
	var username: String? { get set }
	var password: String? { get set }
	var cleanSession: Bool { get set }
	var keepAlive: UInt16 { get set }
	var willMessage: MQTT5Message? { get set }
	var connectProperties: MQTTConnectProperties? { get set }
	var authProperties: MQTTAuthProperties? { get set }

	/* Basic Properties */

	/* CONNNEC/DISCONNECT */

//	func connect() -> Bool
	func connect(timeout: TimeInterval) -> Bool
	func disconnect()
	func ping()

	/* CONNNEC/DISCONNECT */

	/* PUBLISH/SUBSCRIBE */

	func subscribe(topic: String, qos: MQTTQoS)
	func subscribe(topics: [MQTTSubscription])

	func unsubscribe(topic: String)
	func unsubscribe(topics: [MQTTSubscription])

//	func publish(_ topic: String, withString string: String, qos: MQTTQoS, DUP: Bool, retained: Bool, properties: MQTTPublishProperties) -> Int
	func publish(message: MQTT5Message, DUP: Bool, retained: Bool, properties: MQTTPublishProperties) -> Int

	/* PUBLISH/SUBSCRIBE */
}
