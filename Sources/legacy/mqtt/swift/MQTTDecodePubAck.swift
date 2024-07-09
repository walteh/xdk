//
//  MQTTDecodePubAck.swift
//  MQTT
//
//  Created by liwei wang on 2021/8/3.
//

import Foundation

public class MQTTDecodePubAck: NSObject {
	var totalCount = 0
	var dataIndex = 0
	var propertyLength: Int = 0

	public var reasonCode: MQTTPUBACKReasonCode?
	public var msgid: UInt16 = 0
	public var reasonString: String?
	public var userProperty: [String: String]?

	public func decodePubAck(fixedHeader _: UInt8, pubAckData: [UInt8]) {
		self.totalCount = pubAckData.count
		self.dataIndex = 0
		// msgid
		let msgidResult = integerCompute(data: pubAckData, formatType: formatInt.formatUint16.rawValue, offset: self.dataIndex)
		self.msgid = UInt16(msgidResult!.res)
		self.dataIndex = msgidResult!.newOffset

		// 3.4.2.1 PUBACK Reason Code

		// The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success) and there are no Properties. In this case the PUBACK has a Remaining Length of 2.
		if self.dataIndex + 1 > pubAckData.count {
			return
		}

		guard let ack = MQTTPUBACKReasonCode(rawValue: pubAckData[dataIndex]) else {
			return
		}
		self.reasonCode = ack
		self.dataIndex += 1

		var protocolVersion = ""
		if let storage = MQTTStorage() {
			protocolVersion = storage.queryMQTTVersion()
		}

		if protocolVersion == "5.0" {
			// 3.4.2.2 PUBACK Properties
			// 3.4.2.2.1 Property Length
			let propertyLengthVariableByteInteger = decodeVariableByteInteger(data: pubAckData, offset: dataIndex)
			self.propertyLength = propertyLengthVariableByteInteger.res
			self.dataIndex = propertyLengthVariableByteInteger.newOffset

			let occupyIndex = self.dataIndex

			while self.dataIndex < occupyIndex + self.propertyLength {
				let resVariableByteInteger = decodeVariableByteInteger(data: pubAckData, offset: dataIndex)
				self.dataIndex = resVariableByteInteger.newOffset
				let propertyNameByte = resVariableByteInteger.res
				guard let propertyName = MQTTPropertyName(rawValue: UInt8(propertyNameByte)) else {
					break
				}

				switch propertyName.rawValue {
				// 3.4.2.2.2 Reason String
				case MQTTPropertyName.reasonString.rawValue:
					guard let result = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
						break
					}
					self.reasonString = result.resStr
					self.dataIndex = result.newOffset

				// 3.4.2.2.3 User Property
				case MQTTPropertyName.userProperty.rawValue:
					var key: String?
					var value: String?
					guard let keyRes = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
						break
					}
					key = keyRes.resStr
					self.dataIndex = keyRes.newOffset

					guard let valRes = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
						break
					}
					value = valRes.resStr
					self.dataIndex = valRes.newOffset

					self.userProperty![key!] = value

				default:
					return
				}
			}
		}
	}
}
