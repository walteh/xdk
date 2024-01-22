//
//  File.swift
//
//
//  Created by walter on 3/7/23.
//

import Foundation

import Logging

import x

/// Outputs logs to a `Console`.
public struct ConsoleLogger: LogHandler {
	public let label: String

	public let fileLogger: FileDestination

	public let url: URL

	/// See `LogHandler.metadata`.
	public var metadata: Logger.Metadata

	/// See `LogHandler.metadataProvider`.
	public var metadataProvider: Logger.MetadataProvider?

	/// See `LogHandler.logLevel`.
	public var logLevel: Logger.Level

	/// The conosle that the messages will get logged to.
	/// Creates a new `ConsoleLogger` instance.
	///
	/// - Parameters:
	///   - label: Unique identifier for this logger.
	///   - console: The console to log the messages to.
	///   - level: The minimum level of message that the logger will output. This defaults to `.debug`, the lowest level.
	///   - metadata: Extra metadata to log with the message. This defaults to an empty dictionary.

	public init(label: String, level: Logger.Level = .debug, metadata: Logger.Metadata = [:], metadataProvider: Logger.MetadataProvider? = nil) {
		self.label = label
		self.metadata = metadata
		self.logLevel = level
		self.metadataProvider = metadataProvider
		let url: URL = .cachesDirectory.appending(component: "\(Bundle.main.bundleIdentifier ?? "unknown").logs.log")
		self.url = url
		self.fileLogger = .init(logFileURL: url)

		print("")
		print("=====================================")
		print("to view logs:")
		print("tail -f -n100 \(url.relativeString.replacingOccurrences(of: "file://", with: ""))")
		print("=====================================")
		print("")
	}

	/// See `LogHandler[metadataKey:]`.
	///
	/// This just acts as a getter/setter for the `.metadata` property.
	public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
		get { return self.metadata[key] }
		set { self.metadata[key] = newValue }
	}

	/// See `LogHandler.log(level:message:metadata:file:function:line:)`.
	public func log(
		level: Logger.Level,
		message: Logger.Message,
		metadata: Logger.Metadata?,
		file: String,
		function: String,
		line: UInt
	) {
		var file = file
		var function = function
		var line = Int(line)
		var metadata = metadata

		if metadata != nil {
			(function, file, line) = metadata!.getCaller()
			metadata!["file"] = nil
			metadata!["line"] = nil
			metadata!["function"] = nil

			if function.contains("(") {
				let mid = function.split(separator: "(")
				function = String(mid.first!) + String(mid[1] == ")" ? "()" : "(...)")
			}
		}

		var text: ConsoleText = ""

		text += "\(level.name)".consoleText(level.style) + " "

		text += formatDate("HH:mm:ss.SSS").consoleText(color: .palette(242)) + " "

		text += "[ ".consoleText(color: .palette(245)) + String(Thread.current.queueName).padding(toLength: 15, withPad: ".", startingAt: 0).consoleText(color: .palette(253)) + " ]".consoleText(color: .palette(245)) + " "

		let dullsep = ":".consoleText(color: .palette(242))

		let filename = fileNameWithoutSuffix(file).consoleText(color: .lightPurple)
		let targetName = targetOfFile(file).consoleText(color: .orange)
		let functionName = function.consoleText(color: .lightBlue)
		let lineName = String(line).consoleText(color: .perrywinkle)

		text += targetName + dullsep + filename + dullsep + functionName + dullsep + lineName + " "

		text += " "
			+ message.description.consoleText()

		let allMetadata = (metadata ?? [:])
			.merging(self.metadata, uniquingKeysWith: { a, _ in a })
			.merging(self.metadataProvider?.get() ?? [:], uniquingKeysWith: { a, _ in a })

		if !allMetadata.isEmpty {
			// only log metadata if not empty
			text += " " + allMetadata.sortedDescriptionWithoutQuotes.consoleText()
		}

		_ = self.fileLogger.send(level, msg: "\(text.terminalStylize())", thread: Thread.current.name ?? "unknown", file: file, function: function, line: Int(line), context: metadata)
	}
}

let formatter = DateFormatter()
let startDate = Date()
let calendar = Calendar.current

private extension Logger.Metadata {
	var sortedDescriptionWithoutQuotes: String {
		let contents = Array(self)
			.sorted(by: { $0.0 < $1.0 })
			.map { "\($0.description.consoleText(color: .palette(243)).terminalStylize())\("=".consoleText(color: .palette(240)).terminalStylize())\("\"\($1)\"".consoleText(color: .palette(196)).terminalStylize())" }
			.joined(separator: " ")
		return " \(contents)"
	}
}

public extension Logger.Level {
	/// Converts log level to console style
	var style: ConsoleStyle {
		switch self {
		case .trace, .debug: return .init(color: .perrywinkle)
		case .info, .notice: return .init(color: .palette(33))
		case .warning: return .warning
		case .error: return .error
		case .critical: return ConsoleStyle(color: .brightRed)
		}
	}

	var name: String {
		switch self {
		case .trace: return "TRC"
		case .debug: return "DBG"
		case .info: return "INF"
		case .notice: return "NTC"
		case .warning: return "WRN"
		case .error: return "ERR"
		case .critical: return "CRT"
		}
	}
}

/// returns the filename of a path
func fileNameOfFile(_ file: String) -> String {
	let fileParts = file.components(separatedBy: "/")
	if let lastPart = fileParts.last {
		return lastPart
	}
	return ""
}

func targetOfFile(_ file: String) -> String {
	let fileParts = file.components(separatedBy: "/")
	if var firstPart = fileParts.first {
		firstPart = firstPart.replacingOccurrences(of: "_swift", with: "").replacingOccurrences(of: "_", with: "/")
		return firstPart
	}
	return ""
}

/// returns the filename without suffix (= file ending) of a path
func fileNameWithoutSuffix(_ file: String) -> String {
	let fileName = fileNameOfFile(file)

	if !fileName.isEmpty {
		let fileNameParts = fileName.components(separatedBy: ".")
		if let firstPart = fileNameParts.first {
			return firstPart
		}
	}
	return ""
}

/// returns a formatted date string
/// optionally in a given abbreviated timezone like "UTC"
func formatDate(_ dateFormat: String, timeZone: String = "") -> String {
	if !timeZone.isEmpty {
		formatter.timeZone = TimeZone(abbreviation: timeZone)
	}
	formatter.calendar = calendar
	formatter.dateFormat = dateFormat
	// let dateStr = formatter.string(from: NSDate() as Date)
	let dateStr = formatter.string(from: Date())
	return dateStr
}

/// returns a uptime string
func uptime() -> String {
	let interval = Date().timeIntervalSince(startDate)

	let hours = Int(interval) / 3600
	let minutes = Int(interval / 60) - Int(hours * 60)
	let seconds = Int(interval) - (Int(interval / 60) * 60)
	let milliseconds = Int(interval.truncatingRemainder(dividingBy: 1) * 1000)

	return String(format: "%0.2d:%0.2d:%0.2d.%03d", arguments: [hours, minutes, seconds, milliseconds])
}

/// returns the json-encoded string value
/// after it was encoded by jsonStringFromDict
func jsonStringValue(_ jsonString: String?, key: String) -> String {
	guard let str = jsonString else {
		return ""
	}

	// remove the leading {"key":" from the json string and the final }
	let offset = key.length + 5
	let endIndex = str.index(str.startIndex,
	                         offsetBy: str.length - 2)
	let range = str.index(str.startIndex, offsetBy: offset) ..< endIndex
	#if swift(>=3.2)
		return String(str[range])
	#else
		return str[range]
	#endif
}

/// turns dict into JSON-encoded string
func jsonStringFromDict(_ dict: [String: Any]) -> String? {
	var jsonString: String?

	// try to create JSON string
	do {
		let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
		jsonString = String(data: jsonData, encoding: .utf8)
	} catch {
		print("SwiftyBeaver could not create JSON from dict.")
	}
	return jsonString
}

func messageToJSON(_ level: Logging.Logger.Level, msg: String,
                   thread: String, file: String, function: String, line: Int, metadata: Logging.Logger.Metadata) -> String?
{
	var dict: [String: Any] = [
		"timestamp": Date().timeIntervalSince1970,
		"level": level.rawValue,
		"message": msg,
		"thread": thread,
		"file": file,
		"function": function,
		"line": line,
	]

	dict["metadata"] = metadata

	return jsonStringFromDict(dict)
}
