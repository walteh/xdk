//
//  File.swift
//
//
//  Created by walter on 3/1/23.
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
		if let queueName = String(validatingUTF8: __dispatch_queue_get_label(nil)) {
			return queueName
		} else if let operationQueueName = OperationQueue.current?.name, !operationQueueName.isEmpty {
			return operationQueueName
		} else if let dispatchQueueName = OperationQueue.current?.underlyingQueue?.label, !dispatchQueueName.isEmpty {
			return dispatchQueueName
		} else {
			return "n/a"
		}
	}
}
