//
//  File.swift
//  
//
//  Created by walter on 1/24/24.
//

import Foundation
import Logging

public struct Caller {
	let file: String
	let function: String
	let line: UInt

	/// returns the filename of a path
	func fileNameOfFile() -> String {
		let fileParts = file.components(separatedBy: "/")
		if let lastPart = fileParts.last {
			return lastPart
		}
		return ""
	}

	func targetOfFile() -> String {
		let fileParts = file.components(separatedBy: "/")
		if var firstPart = fileParts.first {
			firstPart = firstPart.replacingOccurrences(of: "", with: "").replacingOccurrences(of: "_", with: "/")
			return firstPart
		}
		return ""
	}
	
	/// returns the filename without suffix (= file ending) of a path
	func fileNameWithoutSuffix() -> String {
		let fileName = fileNameOfFile()

		if !fileName.isEmpty {
			let fileNameParts = fileName.components(separatedBy: ".")
			if let firstPart = fileNameParts.first {
				return firstPart
			}
		}
		return ""
	}

	public func format<T: PrettyCallerFormatter>(with formatter: T = NoopPrettyCallFormatter()) -> T.OUTPUT {
		
		var functionStr = ""
		if function.contains("(") {
			let mid = function.split(separator: "(")
			functionStr = String(mid.first!) + String(mid[1] == ")" ? "()" : "(...)")
		} else {
			functionStr = function
		}

		let dullsep = formatter.format(seperator: ":")
		let spacesep = formatter.format(seperator: " ")
		
		_ = formatter.format(function: functionStr) // not in use right now, but maybe later
		let filename = formatter.format(file: fileNameOfFile())
		let targetName = formatter.format(target: targetOfFile())
		let lineName = formatter.format(line: String(line))
				
		return targetName + spacesep + filename + dullsep + lineName
	}

}

public protocol PrettyCallerFormatter {
	associatedtype OUTPUT: CustomStringConvertible, RangeReplaceableCollection
	func format(function: String) -> OUTPUT
	func format(line: String) -> OUTPUT
	func format(file: String) -> OUTPUT
	func format(target: String) -> OUTPUT
	func format(seperator: String) -> OUTPUT
}


public struct NoopPrettyCallFormatter: PrettyCallerFormatter {
	public init () {}
	public func format(function: String) -> String {
		return function
	}
	public	func format(line: String) -> String {
			return line

		}
	public		func format(file: String) -> String {
				return file
	
			}
	public			func format(target: String) -> String {
					return target
		
				}
	public			func format(seperator: String) -> String {
						return seperator
			
					}
}

public extension Logging.Logger.Metadata {
	func getCaller() -> Caller {
		return Caller(
			file: self["file"]?.description ?? "",
			function: self["function"]?.description ?? "",
			line: (try? UInt(self["line"]?.description ?? "", format: .number
		)) ?? 0)
	}
	
	mutating func clearCaller() {
		self.removeValue(forKey: "file")
		self.removeValue(forKey: "line")
		self.removeValue(forKey: "function")
	}
}
