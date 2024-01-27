//
//  Config.swift
//  app
//
//  Created by walter on 10/23/22.
//

import Foundation

func IS_BEING_DEBUGGED() -> Bool {
	return getppid() != 1
}

func IS_BEING_PREVIEWED() -> Bool {
	return (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] ?? "0") == "1"
}

public protocol ConfigAPI {
	func get(key: String) -> Result<String, Error>
	func get(file: String) -> Result<Data, Error>
}

func Get(key: String, using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: key)
}

func Get(file: String, using configAPI: ConfigAPI) -> Result<Data, Error> {
	return configAPI.get(file: file)
}

func GetBundleName(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleName")
}

func GetVersion(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleShortVersionString")
}

func GetBuild(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleVersion")
}

func GetBuildWithDebugFlag(using configAPI: ConfigAPI) -> Result<String, Error> {
	var err: Error? = nil
	guard let build = GetBuild(using: configAPI).to(&err) else {
		return .failure(x.error("failed to get build", root: err))
	}

	return .success("\(build)\(IS_BEING_DEBUGGED() ? " [debug]" : "")")
}

func GetMinimumOSVersion(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "MinimumOSVersion")
}

func GetCopyrightNotice(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "NSHumanReadableCopyright")
}

func GetBundleIdentifier(using configAPI: ConfigAPI) -> Result<String, Error> {
	return configAPI.get(key: "CFBundleIdentifier")
}

@frozen public struct BundleConfig: ConfigAPI {
	let bundle: Bundle

	init(bundle: Bundle) {
		self.bundle = bundle
	}

	public func get(key: String) -> Result<String, Error> {
		return .success(self.bundle.infoDictionary?[key] as? String ?? "")
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
