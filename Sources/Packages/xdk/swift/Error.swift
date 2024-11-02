//
//  Error.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation
import Logging
import Err

// public func Err(_ str: String, root: (any Swift.Error)? = nil, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> TError {
// 	return TError(str, root: root, alias: alias, __file: __file, __function: __function, __line: __line)
// }

public extension x {
	@discardableResult
	// @available(*, deprecated, message: "use Err.error instead")
	static func error(_ str: String, root: (any Swift.Error)? = nil, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> MError {
		return MError(str, root: root,  __file: __file, __function: __function, __line: __line)
	}

	@discardableResult
	// @available(*, deprecated, message: "use Err.error instead")
	static func error(status: OSStatus, alias: (any Swift.Error)? = nil, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> MError {
		return MError("[OSStatus=\(status)]",  __file: __file, __function: __function, __line: __line)
	}
}

