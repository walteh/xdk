//
//  FramePubRec.swift
//  MQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT PUBREC packet
struct FramePubRec: Frame {
	var packetFixedHeaderType: UInt8 = FrameType.pubrec.rawValue

	// --- Attributes

	var msgid: UInt16

	// --- Attributes End

	// 3.5.2.1 PUBREC Reason Code
	public var reasonCode: MQTTPUBRECReasonCode?

	// 3.5.2.2 PUBREC Properties
	public var pubRecProperties: MQTTDecodePubRec?
	// 3.5.2.2.2 Reason String
	public var reasonString: String?
	// 3.5.2.2.3 User Property
	public var userProperties: [String: String]?

	/// MQTT 3.1.1
	init(msgid: UInt16) {
		self.msgid = msgid
	}

	/// MQTT 5.0
	init(msgid: UInt16, reasonCode: MQTTPUBRECReasonCode) {
		self.msgid = msgid
		self.reasonCode = reasonCode
	}
}

extension FramePubRec {
	func fixedHeader() -> [UInt8] {
		var header = [UInt8]()
		header += [FrameType.pubrec.rawValue]

		return header
	}

	func variableHeader5() -> [UInt8] {
		// 3.5.2 MSB+LSB
		var header = self.msgid.hlBytes
		// 3.5.2.1 PUBACK Reason Code
		header += [self.reasonCode!.rawValue]

		// MQTT 5.0
		header += beVariableByteInteger(length: self.properties().count)

		return header
	}

	func payload5() -> [UInt8] { return [] }

	func properties() -> [UInt8] {
		var properties = [UInt8]()

		// 3.5.2.2.2 Reason String
		if let reasonString = self.reasonString {
			properties += getMQTTPropertyData(type: MQTTPropertyName.reasonString.rawValue, value: reasonString.bytesWithLength)
		}

		// 3.5.2.2.3 User Property
		if let userProperty = self.userProperties {
			let dictValues = [String](userProperty.values)
			for value in dictValues {
				properties += getMQTTPropertyData(type: MQTTPropertyName.userProperty.rawValue, value: value.bytesWithLength)
			}
		}

		return properties
	}

	func allData() -> [UInt8] {
		var allData = [UInt8]()

		allData += self.fixedHeader()
		allData += self.variableHeader5()
		allData += self.properties()
		allData += self.payload5()

		return allData
	}

	func variableHeader() -> [UInt8] { return self.msgid.hlBytes }

	func payload() -> [UInt8] { return [] }
}

extension FramePubRec: InitialWithBytes {
	init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
		guard packetFixedHeaderType == FrameType.pubrec.rawValue else {
			return nil
		}
		guard bytes.count >= 2 else {
			return nil
		}

		self.msgid = UInt16(bytes[0]) << 8 + UInt16(bytes[1])

		self.pubRecProperties = MQTTDecodePubRec()
		self.pubRecProperties!.decodePubRec(fixedHeader: packetFixedHeaderType, pubAckData: bytes)
	}
}

extension FramePubRec: CustomStringConvertible {
	var description: String {
		return "PUBREC(id: \(self.msgid))"
	}
}
