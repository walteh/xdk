//
//  Config.swift
//  app
//
//  Created by walter on 10/23/22.
//

import Foundation

public protocol ConfigAPI {
	func get(key: String) -> Result<String, Error>
	func get(file: String) -> Result<Data, Error>
}

public func IS_BEING_UNIT_TESTED() -> Bool {
	return NSClassFromString("XCTestCase") != nil
}

public func IS_BEING_DEBUGGED() -> Bool {
	return getppid() != 1
}

public func IS_BEING_PREVIEWED() -> Bool {
	return (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] ?? "0") == "1"
}

public func Get(key: String, using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: key)
}

public func Get(file: String, using configAPI: ConfigAPI) -> Result<Data, Error> {
	return configAPI.get(file: file)
}

public func GetBundleName(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleName")
}

public func GetVersion(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleShortVersionString")
}

public func GetBuild(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleVersion")
}

public func GetBuildWithDebugFlag(using configAPI: ConfigAPI) -> Result<String, Error> {
	var err: Error? = nil
	guard let build = GetBuild(using: configAPI).to(&err) else {
		return .failure(x.error("failed to get build", root: err))
	}

	return .success("\(build)\(IS_BEING_DEBUGGED() ? " [debug]" : "")")
}

public func GetMinimumOSVersion(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "MinimumOSVersion")
}

public func GetCopyrightNotice(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "NSHumanReadableCopyright")
}

public func GetBundleIdentifier(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleIdentifier")
}

@frozen public struct NoopConfig: ConfigAPI {
	let inMemoryConfig: [String: String]
	let inMemoryFiles: [String: Data]

	public init(inMemoryConfig: [String: String] = [:], inMemoryFiles: [String: Data] = [:]) {
		self.inMemoryConfig = inMemoryConfig
		self.inMemoryFiles = inMemoryFiles
	}

	public func get(key: String) -> Result<String, Error> {
		return .success(self.inMemoryConfig[key] ?? "")
	}

	public func get(file: String) -> Result<Data, Error> {
		return .success(self.inMemoryFiles[file] ?? Data())
	}
}

@frozen public struct BundleConfig: ConfigAPI {
	let bundle: Bundle

	public init(bundle: Bundle) {
		self.bundle = bundle
	}

	public func get(key: String) -> Result<String, Error> {
		let res = self.bundle.infoDictionary?[key] as? String ?? ""
		if res.isEmpty {
			return .failure(x.error("key not found").info("key", key))
		}
		return .success(res)
	}

	public func get(file: String) -> Result<Data, Error> {
		var err: Error? = nil

		guard let ext = file.split(separator: ".").last else {
			return .failure(x.error("unable to determine file extension").info("file", file))
		}

		// for bun in Bundle.allBundles {
		guard let filepath = bundle.path(forResource: file, ofType: ext.string) else {
			return .failure(x.error("file not found: could not find \(file)"))
		}

		guard let data = Result.X { try Data(contentsOf: URL(fileURLWithPath: filepath), options: .mappedIfSafe) }.to(&err) else {
			return .failure(x.error("failed to read file", root: err).info("filepath", filepath))
		}

		return .success(data)
	}
}
