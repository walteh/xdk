//
//  Logging.swift
//  app
//
//  Created by walter on 9/29/22.
//

import Foundation
import Logging
import ServiceContextModule
import Err
import LogEvent

public extension x {
	// @available(*, deprecated, message: "use LogEvent instead")
	static func log(_ level: Logging.Logger.Level = .info, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> LogEvent {
		return LogEvent(level, __file: __file, __function: __function, __line: __line)
	}
}
