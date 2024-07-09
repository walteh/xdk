//
//  MQTTStorage.swift
//  MQTT
//
//  Created by JianBo on 2019/10/6.
//  Copyright © 2019 emqtt.io. All rights reserved.
//

import Foundation

protocol MQTTStorageProtocol {
	var clientID: String { get set }

	init?(by clientID: String)

	func write(_ frame: FramePublish) -> Bool

	func write(_ frame: FramePubRel) -> Bool

	func remove(_ frame: FramePublish)

	func remove(_ frame: FramePubRel)

	func synchronize() -> Bool

	/// Read all stored messages by saving order
	func readAll() -> [Frame]
}

final class MQTTStorage: MQTTStorageProtocol {
	var clientID: String = ""

	var userDefault: UserDefaults = .init()

	var versionDefault: UserDefaults = .init()

	init?() {
		self.versionDefault = UserDefaults()
	}

	init?(by clientID: String) {
		guard let userDefault = UserDefaults(suiteName: MQTTStorage.name(clientID)) else {
			return nil
		}

		self.clientID = clientID
		self.userDefault = userDefault
	}

	deinit {
		userDefault.synchronize()
		versionDefault.synchronize()
	}

	func setMQTTVersion(_ version: String) {
		self.versionDefault.set(version, forKey: "mqtt_mqtt_version")
	}

	func queryMQTTVersion() -> String {
		self.versionDefault.string(forKey: "mqtt_mqtt_version") ?? "3.1.1"
	}

	func write(_ frame: FramePublish) -> Bool {
		guard frame.qos > .qos0 else {
			return false
		}
		self.userDefault.set(frame.bytes(version: self.queryMQTTVersion()), forKey: self.key(frame.msgid))
		return true
	}

	func write(_ frame: FramePubRel) -> Bool {
		self.userDefault.set(frame.bytes(version: self.queryMQTTVersion()), forKey: self.key(frame.msgid))
		return true
	}

	func remove(_ frame: FramePublish) {
		self.userDefault.removeObject(forKey: self.key(frame.msgid))
	}

	func remove(_ frame: FramePubRel) {
		self.userDefault.removeObject(forKey: self.key(frame.msgid))
	}

	func remove(_ frame: Frame) {
		if let pub = frame as? FramePublish {
			self.userDefault.removeObject(forKey: self.key(pub.msgid))
		} else if let rel = frame as? FramePubRel {
			self.userDefault.removeObject(forKey: self.key(rel.msgid))
		}
	}

	func synchronize() -> Bool {
		return self.userDefault.synchronize()
	}

	func readAll() -> [Frame] {
		return self.__read(needDelete: false)
	}

	func takeAll() -> [Frame] {
		return self.__read(needDelete: true)
	}

	private func key(_ msgid: UInt16) -> String {
		return "\(msgid)"
	}

	private class func name(_ clientID: String) -> String {
		return "mqtt-\(clientID)"
	}

	private func parse(_ bytes: [UInt8]) -> (UInt8, [UInt8])? {
		// FramePubRel is 4 bytes long
		guard bytes.count > 3 else {
			return nil
		}
		/// bytes 1..<5 may be 'Remaining Length'
		for i in 1 ..< min(5, bytes.count) {
			if (bytes[i] & 0x80) == 0 {
				return (bytes[0], Array(bytes.suffix(from: i + 1)))
			}
		}

		return nil
	}

	private func __read(needDelete: Bool) -> [Frame] {
		var frames = [Frame]()
		let allObjs = self.userDefault.dictionaryRepresentation().sorted { k1, k2 in
			return k1.key < k2.key
		}
		for (k, v) in allObjs {
			guard let bytes = v as? [UInt8] else { continue }
			guard let parsed = parse(bytes) else { continue }

			if needDelete {
				self.userDefault.removeObject(forKey: k)
			}

			if let f = FramePublish(packetFixedHeaderType: parsed.0, bytes: parsed.1) {
				frames.append(f)
			} else if let f = FramePubRel(packetFixedHeaderType: parsed.0, bytes: parsed.1) {
				frames.append(f)
			}
		}
		return frames
	}
}
