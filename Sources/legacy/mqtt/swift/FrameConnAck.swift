//
//  FrameConnAck.swift
//  MQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

struct FrameConnAck: Frame {
	var packetFixedHeaderType: UInt8 = FrameType.connack.rawValue

	// --- Attributes

	/// MQTT 3.1.1
	var returnCode: MQTTConnAck?

	/// MQTT 5.0
	var reasonCode: MQTTCONNACKReasonCode?

	// 3.2.2.1.1 Session Present
	var sessPresent: Bool = false

	// --- Attributes End

	// 3.2.2.3 CONNACK Properties
	var connackProperties: MQTTDecodeConnAck?
	var propertiesBytes: [UInt8]?
	// 3.2.3 CONNACK Payload
	// The CONNACK packet has no Payload.

	/// MQTT 3.1.1
	init(returnCode: MQTTConnAck) {
		self.returnCode = returnCode
	}

	/// MQTT 5.0
	init(code: MQTTCONNACKReasonCode) {
		self.reasonCode = code
	}
}

extension FrameConnAck {
	func fixedHeader() -> [UInt8] {
		var header = [UInt8]()
		header += [FrameType.connack.rawValue]

		return header
	}

	func variableHeader5() -> [UInt8] {
		return [self.sessPresent.bit, self.reasonCode!.rawValue]
	}

	func payload5() -> [UInt8] { return [] }

	func properties() -> [UInt8] { return self.propertiesBytes ?? [] }

	func allData() -> [UInt8] {
		var allData = [UInt8]()

		allData += self.fixedHeader()
		allData += self.variableHeader5()
		allData += self.properties()
		allData += self.payload5()

		return allData
	}

	func variableHeader() -> [UInt8] {
		return [self.sessPresent.bit, self.returnCode!.rawValue]
	}

	func payload() -> [UInt8] { return [] }
}

extension FrameConnAck: InitialWithBytes {
	init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
		guard packetFixedHeaderType == FrameType.connack.rawValue else {
			return nil
		}

		guard bytes.count >= 2 else {
			return nil
		}

		self.sessPresent = Bool(bit: bytes[0] & 0x01)

		let mqtt5ack = MQTTCONNACKReasonCode(rawValue: bytes[1])
		self.reasonCode = mqtt5ack

		let ack = MQTTConnAck(rawValue: bytes[1])
		self.returnCode = ack

		self.propertiesBytes = bytes
		self.connackProperties = MQTTDecodeConnAck()
		self.connackProperties!.properties(connackData: bytes)
	}
}

extension FrameConnAck: CustomStringConvertible {
	var description: String {
		return "CONNACK(code: \(String(describing: self.reasonCode)), sp: \(self.sessPresent))"
	}
}
