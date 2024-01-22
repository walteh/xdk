//
//  Environment.swift
//  app
//
//  Created by walter on 10/23/22.
//

import Foundation

// enum ConfigurationEnvironment: String {
// 	case dev_debug = "dev.debug"
// 	case dev_release = "dev.release"
// }

// public extension XEnvironment {
// 	var apiGatewayHost: String {
// 		switch self.environment {
// 		case .dev_debug, .dev_release:
// 			return "us-dev02.api.nugg.xyz"
// 		}
// 	}

// 	var appsyncHost: String {
// 		switch self.environment {
// 		case .dev_debug, .dev_release:
// 			return "graph.us-dev02.api.nugg.xyz"
// 		}
// 	}

// 	var appsyncAPIKey: String {
// 		switch self.environment {
// 		case .dev_debug, .dev_release:
// 			return "da2-2rnncyvmd5aenc3kn5p3t5byiq"
// 		}
// 	}

// 	var keychainGroup: String {
// 		switch self.environment {
// 		case .dev_debug, .dev_release:
// 			return "4497QJSAD3.main.keychain.group"
// 		}
// 	}
// }

extension x {
	typealias Config = XConfig
}

public struct XConfig {
	let config: [String: String]

	init(name: String, config: [String: [String: String]]) {
		guard let currentConfiguration = x.Env.readFromInfoPlist(withKey: name) else {
			fatalError("CURRENT_ENVIRONMENT NOT DEFINED")
		}

		guard let values = config[currentConfiguration] else {
			fatalError("CURRENT_ENVIRONMENT NOT DEFINED")
		}

		var configuration: [String: String] = [:]

		for (k, v) in values {
			configuration[k] = x.Env.readFromInfoPlist(withKey: v)
		}

		self.config = configuration
	}

	public func get(_ str: String) -> String {
		return self.config[str] ?? ""
	}
}
