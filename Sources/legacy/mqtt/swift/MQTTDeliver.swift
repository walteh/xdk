//
//  MQTTDeliver.swift
//  MQTT
//
//  Created by HJianBo on 2019/5/2.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Dispatch
import Foundation

protocol MQTTDeliverProtocol: AnyObject {
	var delegateQueue: DispatchQueue { get set }

	func deliver(_ deliver: MQTTDeliver, wantToSend frame: Frame)
}

private struct InflightFrame {
	/// The infligth frame maybe a `FramePublish` or `FramePubRel`
	var frame: Frame

	var timestamp: TimeInterval

	init(frame: Frame) {
		self.init(frame: frame, timestamp: Date(timeIntervalSinceNow: 0).timeIntervalSince1970)
	}

	init(frame: Frame, timestamp: TimeInterval) {
		self.frame = frame
		self.timestamp = timestamp
	}
}

extension [InflightFrame] {
	func filterMap(isIncluded: (Element) -> (Bool, Element)) -> [Element] {
		var tmp = [Element]()
		for e in self {
			let res = isIncluded(e)
			if res.0 {
				tmp.append(res.1)
			}
		}
		return tmp
	}
}

class MessageQueueController {
	fileprivate var mqueue = [Frame]()
	private let semaphore = DispatchSemaphore(value: 1)

	func append(_ frame: Frame) {
		self.semaphore.wait()
		self.mqueue.append(frame)
		self.semaphore.signal()
	}

	func takeFirst() -> Frame? {
		self.semaphore.wait()
		if self.mqueue.isEmpty { return nil }
		let frame = self.mqueue.remove(at: 0)
		self.semaphore.signal()
		return frame
	}

	func removeAll() {
		self.semaphore.wait()
		self.mqueue.removeAll()
		self.semaphore.signal()
	}

	func isQueueEmpty() -> Bool {
		self.semaphore.wait()
		let result = self.mqueue.count == 0
		self.semaphore.signal()
		return result
	}

	func isQueueFull(mqueueSize: UInt) -> Bool {
		self.semaphore.wait()
		let result = self.mqueue.count >= mqueueSize
		self.semaphore.signal()
		return result
	}
}

// MQTTDeliver
class MQTTDeliver: NSObject {
	/// The dispatch queue is used by delivering frames in serially
	private var deliverQueue = DispatchQueue(label: "deliver.mqtt.emqx", qos: .default)

	weak var delegate: MQTTDeliverProtocol?

	fileprivate var inflight = [InflightFrame]()

	fileprivate var mqueue = MessageQueueController()

	var mqueueSize: UInt = 1000

	var inflightWindowSize: UInt = 10

	/// Retry time interval millisecond
	var retryTimeInterval: Double = 5000

	private var awaitingTimer: MQTTTimer?

	var isQueueEmpty: Bool { return self.mqueue.isQueueEmpty() }
	var isQueueFull: Bool { return self.mqueue.isQueueFull(mqueueSize: self.mqueueSize) }
	var isInflightFull: Bool { return self.inflight.count >= self.inflightWindowSize }
	var isInflightEmpty: Bool { return self.inflight.count == 0 }

	var storage: MQTTStorage?

	func recoverSessionBy(_ storage: MQTTStorage) {
		let frames = storage.takeAll()
		guard frames.count >= 0 else {
			return
		}

		// Sync to push the frame to mqueue for avoiding overcommit
		self.deliverQueue.sync {
			for f in frames {
				self.mqueue.append(f)
			}
			self.storage = storage
			printInfo("Deliver recover \(frames.count) msgs")
			printDebug("Recover message \(frames)")
		}

		self.deliverQueue.async { [weak self] in
			guard let self else { return }
			self.tryTransport()
		}
	}

	/// Add a FramePublish to the message queue to wait for sending
	///
	/// return false means the frame is rejected because of the buffer is full
	func add(_ frame: FramePublish) -> Bool {
		var full = false
		self.deliverQueue.sync {
			full = self.isQueueFull
		}

		guard !full else {
			printError("Sending buffer is full, frame \(frame) has been rejected to add.")
			return false
		}

		// Sync to push the frame to mqueue for avoiding overcommit
		self.deliverQueue.sync {
			self.mqueue.append(frame)
			_ = self.storage?.write(frame)
		}

		self.deliverQueue.async { [weak self] in
			guard let self else { return }
			self.tryTransport()
		}

		return true
	}

	/// Acknowledge a PUBLISH/PUBREL by msgid
	func ack(by frame: Frame) {
		var msgid: UInt16

		if let puback = frame as? FramePubAck { msgid = puback.msgid }
		else if let pubrec = frame as? FramePubRec { msgid = pubrec.msgid }
		else if let pubcom = frame as? FramePubComp { msgid = pubcom.msgid }
		else { return }

		self.deliverQueue.async { [weak self] in
			guard let self else { return }
			let acked = self.ackInflightFrame(withMsgid: msgid, type: frame.type)
			if acked.count == 0 {
				printWarning("Acknowledge by \(frame), but not found in inflight window")
			} else {
				// TODO: ACK DONT DELETE PUBREL
				for f in acked {
					if frame is FramePubAck || frame is FramePubComp {
						self.storage?.remove(f)
					}
				}
				printDebug("Acknowledge frame id \(msgid) success, acked: \(acked)")
				self.tryTransport()
			}
		}
	}

	/// Clean Inflight content to prevent message blocked, when next connection established
	///
	/// !!Warning: it's a temporary method for hotfix #221
	func cleanAll() {
		self.deliverQueue.sync { [weak self] in
			guard let self else { return }
			self.mqueue.removeAll()
			self.inflight.removeAll()
		}
	}
}

// MARK: Private Funcs

extension MQTTDeliver {
	// try transport a frame from mqueue to inflight
	private func tryTransport() {
		if self.isQueueEmpty || self.isInflightFull { return }

		// take out the earliest frame
		if let frame = mqueue.takeFirst() {
			self.deliver(frame)

			// keep trying after a transport
			self.tryTransport()
		}
	}

	/// Try to deliver a frame
	private func deliver(_ frame: Frame) {
		if frame.qos == .qos0 {
			// Send Qos0 message, whatever the in-flight queue is full
			// TODO: A retrict deliver mode is need?
			self.sendfun(frame)
		} else {
			self.sendfun(frame)
			self.inflight.append(InflightFrame(frame: frame))

			// Start a retry timer for resending it if it not receive PUBACK or PUBREC
			if self.awaitingTimer == nil {
				self.awaitingTimer = MQTTTimer.every(self.retryTimeInterval / 1000.0, name: "awaitingTimer") { [weak self] in
					guard let self else { return }
					self.deliverQueue.async {
						self.redeliver()
					}
				}
			}
		}
	}

	/// Attempt to redeliver in-flight messages
	private func redeliver() {
		if self.isInflightEmpty {
			// Revoke the awaiting timer
			self.awaitingTimer = nil
			return
		}

		let nowTimestamp = Date(timeIntervalSinceNow: 0).timeIntervalSince1970
		for (idx, frame) in self.inflight.enumerated() {
			if (nowTimestamp - frame.timestamp) >= (self.retryTimeInterval / 1000.0) {
				var duplicatedFrame = frame
				duplicatedFrame.frame.dup = true
				duplicatedFrame.timestamp = nowTimestamp

				self.inflight[idx] = duplicatedFrame

				printInfo("Re-delivery frame \(duplicatedFrame.frame)")
				self.sendfun(duplicatedFrame.frame)
			}
		}
	}

	@discardableResult
	private func ackInflightFrame(withMsgid msgid: UInt16, type: FrameType) -> [Frame] {
		var ackedFrames = [Frame]()
		self.inflight = self.inflight.filterMap { frame in

			// -- ACK for PUBLISH
			if let publish = frame.frame as? FramePublish,
			   publish.msgid == msgid
			{
				if publish.qos == .qos2, type == .pubrec { // -- Replace PUBLISH with PUBREL
					let pubrel = FramePubRel(msgid: publish.msgid)

					var nframe = frame
					nframe.frame = pubrel
					nframe.timestamp = Date(timeIntervalSinceNow: 0).timeIntervalSince1970

					_ = self.storage?.write(pubrel)
					self.sendfun(pubrel)

					ackedFrames.append(publish)
					return (true, nframe)
				} else if publish.qos == .qos1, type == .puback {
					ackedFrames.append(publish)
					return (false, frame)
				}
			}

			// -- ACK for PUBREL
			if let pubrel = frame.frame as? FramePubRel,
			   pubrel.msgid == msgid, type == .pubcomp
			{
				ackedFrames.append(pubrel)
				return (false, frame)
			}
			return (true, frame)
		}

		return ackedFrames
	}

	private func sendfun(_ frame: Frame) {
		guard let delegate = self.delegate else {
			printError("The deliver delegate is nil!!! the frame will be drop: \(frame)")
			return
		}

		if frame.qos == .qos0 {
			if let p = frame as? FramePublish { self.storage?.remove(p) }
		}

		delegate.delegateQueue.async {
			delegate.deliver(self, wantToSend: frame)
		}
	}
}

// For tests
extension MQTTDeliver {
	func t_inflightFrames() -> [Frame] {
		var frames = [Frame]()
		for f in self.inflight {
			frames.append(f.frame)
		}
		return frames
	}

	func t_queuedFrames() -> [Frame] {
		return self.mqueue.mqueue
	}
}
