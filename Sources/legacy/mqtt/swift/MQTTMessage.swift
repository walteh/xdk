//
//  MQTTMessage.swift
//  MQTT
//
//  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
//  Copyright (c) 2015 emqx.io. All rights reserved.
//

import Foundation

/// MQTT Message
public class MQTTMessage: NSObject {
	public var qos = MQTTQoS.qos1

	public var topic: String

	public var payload: [UInt8]

	public var retained = false

	/// The `duplicated` property show that this message maybe has be received before
	///
	/// - note: Readonly property
	public var duplicated = false

	/// Return the payload as a utf8 string if possible
	///
	/// It will return nil if the payload is not a valid utf8 string
	public var string: String? {
		return NSString(bytes: self.payload, length: self.payload.count, encoding: String.Encoding.utf8.rawValue) as String?
	}

	public init(topic: String, string: String, qos: MQTTQoS = .qos1, retained: Bool = false) {
		self.topic = topic
		self.payload = [UInt8](string.utf8)
		self.qos = qos
		self.retained = retained
	}

	public init(topic: String, payload: [UInt8], qos: MQTTQoS = .qos1, retained: Bool = false) {
		self.topic = topic
		self.payload = payload
		self.qos = qos
		self.retained = retained
	}
}

public extension MQTTMessage {
	override var description: String {
		return "MQTTMessage(topic: \(self.topic), qos: \(self.qos), payload: \(self.payload.summary))"
	}
}

// For test
extension MQTTMessage {
	var t_pub_frame: FramePublish {
		var frame = FramePublish(topic: topic, payload: payload, qos: qos, msgid: 0)
		frame.retained = self.retained
		frame.dup = self.duplicated
		return frame
	}
}
