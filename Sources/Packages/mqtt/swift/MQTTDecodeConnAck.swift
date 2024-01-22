//
//  MQTTDecodeConnAck.swift
//  MQTT
//
//  Created by liwei wang on 2021/7/26.
//

import Foundation

public class MQTTDecodeConnAck: NSObject {
	//    var connackData: [UInt8]
//
	//    init(connackData: [UInt8]) {
	//        connackData = connackData
	//    }

	// 3.2.2.3 CONNACK Properties
	// 3.2.2.3.1 Property Length
	public var propertyLength: Int?
	// 3.2.2.3.2 Session Expiry Interval
	public var sessionExpiryInterval: UInt32?
	// 3.2.2.3.3 Receive Maximum
	public var receiveMaximum: UInt16?
	// 3.2.2.3.4 Maximum QoS
	public var maximumQoS: MQTTQoS?
	// 3.2.2.3.5 Retain Available
	public var retainAvailable: Bool?
	// 3.2.2.3.6 Maximum Packet Size
	public var maximumPacketSize: UInt32?
	// 3.2.2.3.7 Assigned Client Identifier
	public var assignedClientIdentifier: String?
	// 3.2.2.3.8 Topic Alias Maximum
	public var topicAliasMaximum: UInt16?
	// 3.2.2.3.9 Reason String
	public var reasonString: String?
	// 3.2.2.3.10 User Property
	public var userProperty: [String: String]?
	// 3.2.2.3.11 Wildcard Subscription Available
	public var wildcardSubscriptionAvailable: Bool?
	// 3.2.2.3.12 Subscription Identifiers Available
	public var subscriptionIdentifiersAvailable: Bool?
	// 3.2.2.3.13 Shared Subscription Available
	public var sharedSubscriptionAvailable: Bool?
	// 3.2.2.3.14 Server Keep Alive
	public var serverKeepAlive: UInt16?
	// 3.2.2.3.15 Response Information
	public var responseInformation: String?
	// 3.2.2.3.16 Server Reference
	public var serverReference: String?
	// 3.2.2.3.17 Authentication Method
	public var authenticationMethod: String?
	// 3.2.2.3.18 Authentication Data
	public var authenticationData = [UInt8]()

	public func properties(connackData: [UInt8]) {
		// 3.2.2.3 CONNACK Properties
		var index = 2 // sessPresent 0 reasonCode 1
		let propertyLengthVariableByteInteger = decodeVariableByteInteger(data: connackData, offset: index)
		self.propertyLength = propertyLengthVariableByteInteger.res
		index = propertyLengthVariableByteInteger.newOffset
		let occupyIndex = index

		var protocolVersion = ""
		if let storage = MQTTStorage() {
			protocolVersion = storage.queryMQTTVersion()
		}

		if protocolVersion == "5.0" {
			// properties
			while index - occupyIndex < self.propertyLength! {
				let resVariableByteInteger = decodeVariableByteInteger(data: connackData, offset: index)
				index = resVariableByteInteger.newOffset
				let propertyNameByte = resVariableByteInteger.res
				guard let propertyName = MQTTPropertyName(rawValue: UInt8(propertyNameByte)) else {
					break
				}

				switch propertyName.rawValue {
				case MQTTPropertyName.sessionExpiryInterval.rawValue:

					let comRes = integerCompute(data: connackData, formatType: formatInt.formatUint32.rawValue, offset: index)
					self.sessionExpiryInterval = UInt32(comRes!.res)
					index = comRes!.newOffset

				case MQTTPropertyName.receiveMaximum.rawValue:

					let comRes = integerCompute(data: connackData, formatType: formatInt.formatUint16.rawValue, offset: index)
					self.receiveMaximum = UInt16(comRes!.res)
					index = comRes!.newOffset

				case MQTTPropertyName.maximumQoS.rawValue:
					if index > connackData.count {
						break
					}
					if connackData[index] & 0x01 > 0 {
						self.maximumQoS = .qos0
					} else {
						self.maximumQoS = .qos1
					}

					index += 1

				case MQTTPropertyName.retainAvailable.rawValue:
					if index > connackData.count {
						break
					}
					if connackData[index] & 0x01 > 0 {
						self.retainAvailable = true
					} else {
						self.retainAvailable = false
					}

					index += 1

				case MQTTPropertyName.maximumPacketSize.rawValue:

					let comRes = integerCompute(data: connackData, formatType: formatInt.formatUint32.rawValue, offset: index)
					self.maximumPacketSize = UInt32(comRes!.res)
					index = comRes!.newOffset

				case MQTTPropertyName.assignedClientIdentifier.rawValue:
					guard let result = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					self.assignedClientIdentifier = result.resStr
					index = result.newOffset

				case MQTTPropertyName.topicAliasMaximum.rawValue:

					let comRes = integerCompute(data: connackData, formatType: formatInt.formatUint16.rawValue, offset: index)
					self.topicAliasMaximum = UInt16(comRes!.res)
					index = comRes!.newOffset

				case MQTTPropertyName.reasonString.rawValue:
					guard let result = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					self.reasonString = result.resStr
					index = result.newOffset

				case MQTTPropertyName.userProperty.rawValue:
					var key: String?
					var value: String?
					guard let keyRes = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					key = keyRes.resStr
					index = keyRes.newOffset

					guard let valRes = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					value = valRes.resStr
					index = valRes.newOffset

					self.userProperty![key!] = value

				case MQTTPropertyName.wildcardSubscriptionAvailable.rawValue:
					if index > connackData.count {
						break
					}
					if connackData[index] & 0x01 > 0 {
						self.wildcardSubscriptionAvailable = true
					} else {
						self.wildcardSubscriptionAvailable = false
					}
					index += 1

				case MQTTPropertyName.subscriptionIdentifiersAvailable.rawValue:
					if index > connackData.count {
						break
					}
					if connackData[index] & 0x01 > 0 {
						self.subscriptionIdentifiersAvailable = true
					} else {
						self.subscriptionIdentifiersAvailable = false
					}
					index += 1

				case MQTTPropertyName.sharedSubscriptionAvailable.rawValue:
					if index > connackData.count {
						break
					}
					if connackData[index] & 0x01 > 0 {
						self.sharedSubscriptionAvailable = true
					} else {
						self.sharedSubscriptionAvailable = false
					}
					index += 1

				case MQTTPropertyName.serverKeepAlive.rawValue:

					let comRes = integerCompute(data: connackData, formatType: formatInt.formatUint16.rawValue, offset: index)
					self.serverKeepAlive = UInt16(comRes!.res)
					index = comRes!.newOffset

				case MQTTPropertyName.responseInformation.rawValue:
					guard let valRes = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					self.responseInformation = valRes.resStr
					index = valRes.newOffset

				case MQTTPropertyName.serverReference.rawValue:
					guard let valRes = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					self.serverReference = valRes.resStr
					index = valRes.newOffset

				case MQTTPropertyName.authenticationMethod.rawValue:
					guard let valRes = unsignedByteToString(data: connackData, offset: index) else {
						break
					}
					self.authenticationMethod = valRes.resStr
					index = valRes.newOffset

				case MQTTPropertyName.authenticationData.rawValue:
					guard let valRes = unsignedByteToBinary(data: connackData, offset: index) else {
						break
					}
					self.authenticationData = valRes.resStr
					index = valRes.newOffset

				default:
					break
				}
			}
		}
	}
}
