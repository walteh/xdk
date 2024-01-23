
import Foundation

public extension x {
	enum Env {
		func mustGet(string: String) -> String {
			guard let res = x.Env.readFromInfoPlist(withKey: string) else {
				fatalError("x.Env.mustGet(string: \(string)) FAILED")
			}
			return res
		}
	}
}

public extension x.Env {
	enum AppInfo {
		static var appName: String {
			return readFromInfoPlist(withKey: "CFBundleName") ?? "(unknown app name)"
		}

		static var version: String {
			return readFromInfoPlist(withKey: "CFBundleShortVersionString") ?? "(unknown app version)"
		}

		static var build: String {
			return readFromInfoPlist(withKey: "CFBundleVersion") ?? "(unknown build number)"
		}

		static var buildWithDebugFlag: String {
			return "\(build)\(isBeingDebugged ? " [debug]" : "")"
		}

		static var minimumOSVersion: String {
			return readFromInfoPlist(withKey: "MinimumOSVersion") ?? "(unknown minimum OSVersion)"
		}

		static var copyrightNotice: String {
			return readFromInfoPlist(withKey: "NSHumanReadableCopyright") ?? "(unknown copyright notice)"
		}

		static var bundleIdentifier: String {
			return readFromInfoPlist(withKey: "CFBundleIdentifier") ?? "(unknown bundle identifier)"
		}

		static var isBeingPreviewed: Bool {
			return (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] ?? "0") == "1"
		}

		static var isBeingDebugged: Bool {
			return getppid() != 1
		}
	}
}

extension x.Env {
	private static let infoPlistDictionary = Bundle.main.infoDictionary

	/// Retrieves and returns associated values (of Type String) from info.Plist of the app.
	public static func readFromInfoPlist(withKey key: String) -> String? {
		return self.infoPlistDictionary?[key] as? String
	}

	enum FileType: String {
		case JSON = "json"
		case GraphQL = "graphql"
	}

	private static func load(fileName: String, ofType: FileType) throws -> Data {
		for bun in Bundle.allBundles {
			if let filepath = bun.path(forResource: fileName, ofType: ofType.rawValue) {
				let data = try Data(contentsOf: URL(fileURLWithPath: filepath), options: .mappedIfSafe)
				return data
			}
		}

		throw x.error("file not found").with(message: "could not find \(fileName).\(ofType.rawValue)")
	}

	private static func load(fileName: String, ofType: FileType) -> Result<Data, Error> {
		return Result.X { try self.load(fileName: fileName, ofType: ofType) }
	}
}
