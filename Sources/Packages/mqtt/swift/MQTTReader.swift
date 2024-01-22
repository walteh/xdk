//
//  MQTTReader.swift
//  MQTT
//
//  Created by HJianBo on 2019/5/21.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// Read tag for AsyncSocket
enum MQTTReadTag: Int {
	case header = 0
	case length
	case payload
}

///
protocol MQTTReaderDelegate: AnyObject {
	func didReceive(_ reader: MQTTReader, connack: FrameConnAck)

	func didReceive(_ reader: MQTTReader, publish: FramePublish)

	func didReceive(_ reader: MQTTReader, puback: FramePubAck)

	func didReceive(_ reader: MQTTReader, pubrec: FramePubRec)

	func didReceive(_ reader: MQTTReader, pubrel: FramePubRel)

	func didReceive(_ reader: MQTTReader, pubcomp: FramePubComp)

	func didReceive(_ reader: MQTTReader, suback: FrameSubAck)

	func didReceive(_ reader: MQTTReader, unsuback: FrameUnsubAck)

	func didReceive(_ reader: MQTTReader, pingresp: FramePingResp)
}

class MQTTReader {
	private var socket: MQTTSocketProtocol

	private weak var delegate: MQTTReaderDelegate?

	private let timeout: TimeInterval = 30000

	/*  -- Reader states -- */
	private var header: UInt8 = 0
	private var length: UInt = 0
	private var data: [UInt8] = []
	private var multiply = 1
	/*  -- Reader states -- */

	init(socket: MQTTSocketProtocol, delegate: MQTTReaderDelegate?) {
		self.socket = socket
		self.delegate = delegate
	}

	func start() {
		self.readHeader()
	}

	func headerReady(_ header: UInt8) {
		self.header = header
		self.readLength()
	}

	func lengthReady(_ byte: UInt8) {
		self.length += UInt(Int(byte & 127) * self.multiply)
		// done
		if byte & 0x80 == 0 {
			if self.length == 0 {
				self.frameReady()
			} else {
				self.readPayload()
			}
			// more
		} else {
			self.multiply *= 128
			self.readLength()
		}
	}

	func payloadReady(_ data: Data) {
		self.data = [UInt8](repeating: 0, count: data.count)
		data.copyBytes(to: &(self.data), count: data.count)
		self.frameReady()
	}

	private func readHeader() {
		self.reset()
		self.socket.readData(toLength: 1, withTimeout: -1, tag: MQTTReadTag.header.rawValue)
	}

	private func readLength() {
		self.socket.readData(toLength: 1, withTimeout: self.timeout, tag: MQTTReadTag.length.rawValue)
	}

	private func readPayload() {
		self.socket.readData(toLength: self.length, withTimeout: self.timeout, tag: MQTTReadTag.payload.rawValue)
	}

	private func frameReady() {
		guard let frameType = FrameType(rawValue: UInt8(header & 0xF0)) else {
			printError("Received unknown frame type, header: \(self.header), data:\(self.data)")
			self.readHeader()
			return
		}

		// XXX: stupid implement

		switch frameType {
		case .connack:
			guard let connack = FrameConnAck(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, connack: connack)
		case .publish:
			guard let publish = FramePublish(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, publish: publish)
		case .puback:
			guard let puback = FramePubAck(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, puback: puback)
		case .pubrec:
			guard let pubrec = FramePubRec(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, pubrec: pubrec)
		case .pubrel:
			guard let pubrel = FramePubRel(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, pubrel: pubrel)
		case .pubcomp:
			guard let pubcomp = FramePubComp(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, pubcomp: pubcomp)
		case .suback:
			guard let frame = FrameSubAck(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, suback: frame)
		case .unsuback:
			guard let frame = FrameUnsubAck(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, unsuback: frame)
		case .pingresp:
			guard let frame = FramePingResp(packetFixedHeaderType: header, bytes: data) else {
				printError("Reader parse \(frameType) failed, data: \(self.data)")
				break
			}
			self.delegate?.didReceive(self, pingresp: frame)
		default:
			break
		}

		self.readHeader()
	}

	private func reset() {
		self.length = 0
		self.multiply = 1
		self.header = 0
		self.data = []
	}
}
