//
//  MQTTTimer.swift
//  MQTT
//
//  Contributed by Jens(https://github.com/jmiltner)
//
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

// modeled after RepeatingTimer by Daniel Galasko: https://medium.com/@danielgalasko/a-background-repeating-timer-in-swift-412cecfd2ef9
/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52)
class MQTTTimer {
	let timeInterval: TimeInterval
	let startDelay: TimeInterval
	let name: String

	init(delay: TimeInterval? = nil, name: String, timeInterval: TimeInterval) {
		self.name = name
		self.timeInterval = timeInterval
		if let delay {
			self.startDelay = delay
		} else {
			self.startDelay = timeInterval
		}
	}

	class func every(_ interval: TimeInterval, name: String, _ block: @escaping () -> Void) -> MQTTTimer {
		let timer = MQTTTimer(name: name, timeInterval: interval)
		timer.eventHandler = block
		timer.resume()
		return timer
	}

	@discardableResult
	class func after(_ interval: TimeInterval, name: String, _ block: @escaping () -> Void) -> MQTTTimer {
		let timer: MQTTTimer? = MQTTTimer(delay: interval, name: name, timeInterval: 0)
		timer?.eventHandler = { [weak timer] in
			block()
			timer?.suspend()
			timer = nil
		}
		timer?.resume()
		return timer!
	}

	/// Execute the tasks concurrently on the target_queue with default QOS
	private static let target_queue = DispatchQueue(label: "io.emqx.MQTT.TimerQueue", qos: .default, attributes: .concurrent)

	/// Execute each timer tasks serially and use the target queue for concurrency among timers
	private lazy var timer: DispatchSourceTimer = {
		let queue = DispatchQueue(label: "io.emqx.MQTT." + self.name, target: MQTTTimer.target_queue)
		let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
		t.schedule(deadline: .now() + self.startDelay, repeating: self.timeInterval > 0 ? Double(self.timeInterval) : Double.infinity)
		t.setEventHandler(handler: { [weak self] in
			self?.eventHandler?()
		})
		return t
	}()

	var eventHandler: (() -> Void)?

	private enum State {
		case suspended
		case resumed
		case canceled
	}

	private var state: State = .suspended

	deinit {
		timer.setEventHandler {}
		timer.cancel()
		/*
		 If the timer is suspended, calling cancel without resuming
		 triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
		 */
		resume()
		eventHandler = nil
	}

	func resume() {
		if self.state == .resumed {
			return
		}
		self.state = .resumed
		self.timer.resume()
	}

	func suspend() {
		if self.state == .suspended {
			return
		}
		self.state = .suspended
		self.timer.suspend()
	}

	/// Manually cancel timer
	func cancel() {
		if self.state == .canceled {
			return
		}
		self.state = .canceled
		self.timer.cancel()
	}
}
