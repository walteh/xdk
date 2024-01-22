//
//  MQTTTests.swift
//  MQTTTests
//
//  Created by CrazyWisdom on 15/12/11.
//  Copyright © 2015年 emqx.io. All rights reserved.
//

import XCTest
@testable import XDKMQTT

// #if IS_PACKAGE
//	@testable import MQTTWebSocket
// #endif

private let host = "localhost"
private let port: UInt16 = 1883
private let sslport: UInt16 = 8883
private let clientID = "ClientForUnitTesting-" + randomCode(length: 6)

private let delegate_queue_key = DispatchSpecificKey<String>()
private let delegate_queue_val = "_custom_delegate_queue_"

class MQTTTests: XCTestCase {
	var deleQueue: DispatchQueue!

	override func setUp() {
		deleQueue = DispatchQueue(label: "cttest")
		deleQueue.setSpecific(key: delegate_queue_key, value: delegate_queue_val)
		super.setUp()
	}

	override func tearDown() {
		super.tearDown()
	}

	func testConnect() {
		let caller = Caller()
		let mqtt = MQTT5(clientID: clientID, host: host, port: port)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.autoReconnect = false

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(mqtt.connState, .connected)

		let topics = ["t/0", "t/1", "t/2"]

		mqtt.subscribe(topic: topics[0])
		mqtt.subscribe(topic: topics[1])
		mqtt.subscribe(topic: topics[2])
		wait_for {
			caller.subs == topics
		}

		mqtt.publish(topic: topics[0], withString: "0", qos: .qos0, retained: false, properties: .init())
		mqtt.publish(topic: topics[1], withString: "1", qos: .qos1, retained: false, properties: .init())
		mqtt.publish(topic: topics[2], withString: "2", qos: .qos2, retained: false, properties: .init())
		wait_for {
			if caller.recvs.count >= 3 {
				let f0 = caller.recvs[0]
				let f1 = caller.recvs[1]
				let f2 = caller.recvs[2]
				XCTAssertEqual(f0.topic, topics[0])
				XCTAssertEqual(f1.topic, topics[1])
				XCTAssertEqual(f2.topic, topics[2])
				return true
			}
			return false
		}

		mqtt.unsubscribe(topic: topics[0])
		mqtt.unsubscribe(topic: topics[1])
		mqtt.unsubscribe(topic: topics[2])
		wait_for {
			caller.subs == []
		}

		mqtt.disconnect()
		wait_for {
			caller.isConnected == false
		}
		XCTAssertEqual(mqtt.connState, .disconnected)
	}

	// This is a basic test of the websocket authentication used by AWS IoT Custom Authorizers
	// https://docs.aws.amazon.com/iot/latest/developerguide/custom-authorizer.html
	func testWebsocketAuthConnect() {
		let caller = Caller()
		let websocket = MQTTWebSocket(uri: "/mqtt")

		websocket.enableSSL = true
		let mqtt = MQTT5(clientID: clientID, host: "iot.nugg.xyz", port: 443, socket: websocket)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.autoReconnect = false
		mqtt.username = clientID
		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(mqtt.connState, .connected)
		let topic = "d/AADDS"
		mqtt.subscribe(topic: topic)
		wait_for {
			if caller.subs.count >= 1 {
				if caller.subs[0] == topic {
					return true
				}
			}
			return false
		}
		mqtt.publish(topic: topic, withString: "0", qos: .qos0, retained: false, properties: .init())
		wait_for {
			if caller.recvs.count >= 1 {
				let f = caller.recvs[0]
				XCTAssertEqual(f.topic, topic)
				return true
			}
			return false
		}
	}

	func testWebsocketConnect() {
		let caller = Caller()
		let websocket = MQTTWebSocket(uri: "/mqtt")
		let mqtt = MQTT5(clientID: clientID, host: host, port: 8083, socket: websocket)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.autoReconnect = false
		// mqtt.enableSSL = true

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(mqtt.connState, .connected)

		let topics = ["t/0", "t/1", "t/2"]

		mqtt.subscribe(topic: topics[0])
		mqtt.subscribe(topic: topics[1])
		mqtt.subscribe(topic: topics[2])
		wait_for {
			caller.subs == topics
		}

		mqtt.publish(topic: topics[0], withString: "0", qos: .qos0, retained: false, properties: .init())
		mqtt.publish(topic: topics[1], withString: "1", qos: .qos1, retained: false, properties: .init())
		mqtt.publish(topic: topics[2], withString: "2", qos: .qos2, retained: false, properties: .init())
		wait_for {
			if caller.recvs.count >= 3 {
				let f0 = caller.recvs[0]
				let f1 = caller.recvs[1]
				let f2 = caller.recvs[2]
				XCTAssertEqual(f0.topic, topics[0])
				XCTAssertEqual(f1.topic, topics[1])
				XCTAssertEqual(f2.topic, topics[2])
				return true
			}
			return false
		}

		mqtt.unsubscribe(topic: topics[0])
		mqtt.unsubscribe(topic: topics[1])
		mqtt.unsubscribe(topic: topics[2])
		wait_for {
			caller.subs == []
		}

		mqtt.disconnect()
		wait_for {
			caller.isConnected == false
		}
		XCTAssertEqual(mqtt.connState, .disconnected)
	}

	func testAutoReconnect() {
		let caller = Caller()
		let mqtt = MQTT5(clientID: clientID, host: host, port: port)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.autoReconnect = true
		mqtt.autoReconnectTimeInterval = 1

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(mqtt.connState, .connected)

		mqtt.internal_disconnect()
		wait_for {
			caller.isConnected == false
		}

		// Waiting for auto-reconnect
		wait_for { caller.isConnected }

		mqtt.disconnect()
		wait_for {
			caller.isConnected == false
		}
		XCTAssertEqual(mqtt.connState, .disconnected)
	}

	func testLongString() {
		let caller = Caller()
		let mqtt = MQTT5(clientID: clientID, host: host, port: port)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.autoReconnect = false

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(mqtt.connState, .connected)

		mqtt.subscribe(topic: "t/#", qos: .qos2)
		wait_for {
			caller.subs == ["t/#"]
		}

		mqtt.publish(topic: "t/1", withString: longStringGen(), qos: .qos2, properties: .init())
		wait_for {
			guard caller.recvs.count > 0 else {
				return false
			}
			XCTAssertEqual(caller.recvs[0].topic, "t/1")
			return true
		}

		mqtt.disconnect()
		wait_for { caller.isConnected == false }
		XCTAssertEqual(mqtt.connState, .disconnected)
	}

	func testProcessSafePub() {
		let caller = Caller()
		let mqtt = MQTT5(clientID: clientID, host: host, port: port)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.autoReconnect = false

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(mqtt.connState, .connected)

		mqtt.subscribe(topic: "t/#", qos: .qos1)
		wait_for {
			caller.subs == ["t/#"]
		}

		mqtt.inflightWindowSize = 10
		mqtt.messageQueueSize = 100

		let concurrentQueue = DispatchQueue(label: "tests.mqtt.emqx", qos: .default, attributes: .concurrent)
		for i in 0 ..< 100 {
			concurrentQueue.async {
				mqtt.publish(topic: "t/\(i)", withString: "m\(i)", qos: .qos1, properties: .init())
			}
		}
		wait_for {
			caller.recvs.count == 100
		}

		mqtt.disconnect()
		wait_for { caller.isConnected == false }
		XCTAssertEqual(mqtt.connState, .disconnected)
	}

	func testOnyWaySSL() {
		let caller = Caller()
		let mqtt = MQTT5(clientID: clientID, host: host, port: sslport)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.enableSSL = true
		mqtt.allowUntrustCACertificate = true

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(caller.isSSL, true)
		XCTAssertEqual(mqtt.connState, .connected)

		mqtt.disconnect()
		wait_for { caller.isConnected == false }
		XCTAssertEqual(mqtt.connState, .disconnected)
	}

	func testTwoWaySLL() {
		let caller = Caller()
		let mqtt = MQTT5(clientID: clientID, host: host, port: sslport)
		mqtt.delegateQueue = deleQueue
		mqtt.delegate = caller
		mqtt.logLevel = .error
		mqtt.enableSSL = true
		mqtt.allowUntrustCACertificate = true

		let clientCertArray = getClientCertFromP12File(certName: "client-keycert", certPassword: "MySecretPassword")

		var sslSettings: [String: NSObject] = [:]
		sslSettings[kCFStreamSSLCertificates as String] = clientCertArray

		mqtt.sslSettings = sslSettings

		_ = mqtt.connect()
		wait_for { caller.isConnected }
		XCTAssertEqual(caller.isSSL, true)
		XCTAssertEqual(mqtt.connState, .connected)

		mqtt.disconnect()
		wait_for { caller.isConnected == false }
		XCTAssertEqual(mqtt.connState, .disconnected)
	}
}

extension MQTTTests {
	func wait_for(line: Int = #line, t: Int = 10, _ fun: @escaping () -> Bool) {
		let exp = XCTestExpectation(description: "line: \(line)")
		let thrd = Thread {
			while true {
				usleep(useconds_t(1000))
				guard fun() else {
					continue
				}
				exp.fulfill()
				break
			}
		}
		thrd.start()
		wait(for: [exp], timeout: TimeInterval(t))
		thrd.cancel()
	}

	private func ms_sleep(_ ms: Int) {
		usleep(useconds_t(ms * 1000))
	}

	func getClientCertFromP12File(certName: String, certPassword: String) -> CFArray? {
		let testBundle = Bundle(for: type(of: self))

		// get p12 file path
		let resourcePath = testBundle.path(forResource: certName, ofType: "p12")

		guard let filePath = resourcePath, let p12Data = NSData(contentsOfFile: filePath) else {
			print("Failed to open the certificate file: \(certName).p12")
			return nil
		}

		// create key dictionary for reading p12 file
		let key = kSecImportExportPassphrase as String
		let options: NSDictionary = [key: certPassword]

		var items: CFArray?
		let securityError = SecPKCS12Import(p12Data, options, &items)

		guard securityError == errSecSuccess else {
			if securityError == errSecAuthFailed {
				print("ERROR: SecPKCS12Import returned errSecAuthFailed. Incorrect password?")
			} else {
				print("Failed to open the certificate file: \(certName).p12")
			}
			return nil
		}

		guard let theArray = items, CFArrayGetCount(theArray) > 0 else {
			return nil
		}

		let dictionary = (theArray as NSArray).object(at: 0)
		guard let identity = (dictionary as AnyObject).value(forKey: kSecImportItemIdentity as String) else {
			return nil
		}
		let certArray = [identity] as CFArray

		return certArray
	}
}

private class Caller: MQTT5Delegate {

	var recvs = [FramePublish]()

	var sents = [UInt16]()

	var acks = [UInt16]()

	var subs = [String]()

	var isConnected = false

	var isSSL = false

	func didConnect(_: mqtt.API, ack: MQTTCONNACKReasonCode, data _: MQTTDecodeConnAck?) {
		assert_in_del_queue()
		if ack == .success { isConnected = true }
	}

	func didPublish(_: mqtt.API, message _: MQTT5Message, id: UInt16) {
		assert_in_del_queue()
		sents.append(id)
	}

	func didPublish(_: mqtt.API, ack: UInt16, data _: MQTTDecodePubAck?) {
		assert_in_del_queue()
		acks.append(ack)
	}

	func didReceive(_: mqtt.API, message: MQTT5Message, id: UInt16, data _: MQTTDecodePublish?) {
		assert_in_del_queue()

		var frame = message.t_pub_frame
		frame.msgid = id
		recvs.append(frame)
	}

	func didSubscribe(_: mqtt.API, topics: NSDictionary, failed _: [String], data _: MQTTDecodeSubAck?) {
		assert_in_del_queue()

		subs = subs + (topics.allKeys as! [String])
	}

	func didUnsubscribe(_: mqtt.API, topics: [String], data _: MQTTDecodeUnsubAck?) {
		assert_in_del_queue()

		subs = subs.filter { e -> Bool in
			!topics.contains(e)
		}
	}

	func didPing(_: MQTTAPI) {
		assert_in_del_queue()
	}

	func didReceivePong(_: MQTTAPI) {
		assert_in_del_queue()
	}

	func didDisconnect(_: MQTTAPI, withError _: Error?) {
		assert_in_del_queue()

		isConnected = false
	}

	func didStateChange(_: mqtt.API, to _: MQTTConnState) {
		assert_in_del_queue()
	}

	func didPublish(_: mqtt.API, complete _: UInt16, data: XDKMQTT.MQTTDecodePubComp?) {
		assert_in_del_queue()
	}

	func didReceive(_: mqtt.API, trust _: SecTrust, completionHandler: @escaping (Bool) -> Void) {
		assert_in_del_queue()

		isSSL = true

		completionHandler(true)
	}

	var disconnectCodes = [MQTTDISCONNECTReasonCode]()
	var authCodes = [MQTTAUTHReasonCode]()

	var recs = [UInt16]()

	func didReceiveDisconnect(_: mqtt.API, reasonCode: MQTTDISCONNECTReasonCode) {
		assert_in_del_queue()
		disconnectCodes.append(reasonCode)
	}

	func didReceiveAuth(_: mqtt.API, reasonCode: MQTTAUTHReasonCode) {
		assert_in_del_queue()
		authCodes.append(reasonCode)
	}

	func didPublish(_: mqtt.API, rec: UInt16, data _: MQTTDecodePubRec?) {
		assert_in_del_queue()
		recs.append(rec)
	}

	func assert_in_del_queue() {
		XCTAssertEqual(delegate_queue_val, DispatchQueue.getSpecific(key: delegate_queue_key))
	}
}

// tools

private func randomCode(length: Int) -> String {
	let base62chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	var code = ""
	for _ in 0 ..< length {
		let random = Int(arc4random_uniform(62))
		let index = base62chars.index(base62chars.startIndex, offsetBy: random)
		code.append(base62chars[index])
	}
	return code
}

private func longStringGen() -> String {
	var string = ""
	let shijing = "燕燕于飞，差池其羽。之子于归，远送于野。瞻望弗及，泣涕如雨。\n" +
		"燕燕于飞，颉之颃之。之子于归，远于将之。瞻望弗及，伫立以泣。\n" +
		"燕燕于飞，下上其音。之子于归，远送于南。瞻望弗及，实劳我心。\n" +
		"仲氏任只，其心塞渊。终温且惠，淑慎其身。先君之思，以勗寡人。\n"

	for _ in 1 ... 100 {
		string.append(shijing)
	}
	return string
}
