//
//  MQTTSubscription.swift
//  MQTT
//
//  Created by liwei wang on 2021/7/15.
//

import Foundation

/// 3.8.3.1 Subscription Options
public class MQTTSubscription {
	public var topic: String
	public var qos = MQTTQoS.qos1
	public var noLocal: Bool = false
	public var retainAsPublished: Bool = false
	public var retainHandling: RetainHandlingOption
	public var subscriptionOptions: Bool = false

	public init(topic: String) {
		self.topic = topic
		self.qos = MQTTQoS.qos1
		self.noLocal = false
		self.retainAsPublished = false
		self.retainHandling = RetainHandlingOption.none
	}

	public init(topic: String, qos: MQTTQoS) {
		self.topic = topic
		self.qos = qos
		self.noLocal = false
		self.retainAsPublished = false
		self.retainHandling = RetainHandlingOption.none
	}

	var subscriptionData: [UInt8] {
		var data = [UInt8]()

		data += self.topic.bytesWithLength

		var options: Int = 0
		switch self.qos {
		case .qos0:
			options = options | 0b0000_0000
		case .qos1:
			options = options | 0b0000_0001
		case .qos2:
			options = options | 0b0000_0010
		default:
			printDebug("topicFilter qos failure")
		}

		switch self.noLocal {
		case true:
			options = options | 0b0000_0100
		case false:
			options = options | 0b0000_0000
		}

		switch self.retainAsPublished {
		case true:
			options = options | 0b0000_1000
		case false:
			options = options | 0b0000_0000
		}

		switch self.retainHandling {
		case RetainHandlingOption.none:
			options = options | 0b0000_0000
		case RetainHandlingOption.sendOnlyWhenSubscribeIsNew:
			options = options | 0b0001_0000
		case RetainHandlingOption.sendOnSubscribe:
			options = options | 0b0010_0000
		}

		if self.subscriptionOptions {
			data += [UInt8(options)]
		}

		return data
	}
}
