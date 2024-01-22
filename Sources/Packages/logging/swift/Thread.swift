//
//  Logger+Thread.swift
//  app
//
//  Created by walter on 9/30/22.
//

import Foundation

extension Thread {
	var isRunningXCTest: Bool {
		threadDictionary.allKeys
			.contains {
				($0 as? String)?
					.range(of: "XCTest", options: .caseInsensitive) != nil
			}
	}

	var threadName: String {
		if isMainThread {
			return "main"
		} else if let threadName = Thread.current.name, !threadName.isEmpty {
			return threadName
		} else {
			return description
		}
	}

	var queueName: String {
		var res = ""
		if let queueName = String(validatingUTF8: __dispatch_queue_get_label(nil)) {
			res = queueName
		} else if let operationQueueName = OperationQueue.current?.name, !operationQueueName.isEmpty {
			res = operationQueueName
		} else if let dispatchQueueName = OperationQueue.current?.underlyingQueue?.label, !dispatchQueueName.isEmpty {
			res = dispatchQueueName
		} else {
			res = "n/a"
		}

		switch res {
		case "com.apple.main-thread":
			return "main"
		case "com.apple.NSURLSession-delegate":
			return "url-session"
		default:
			return res.replacingOccurrences(of: "com.apple.", with: "")
		}
	}
}
