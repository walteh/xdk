// swift-tools-version: 6.0

import CompilerPluginSupport
import Foundation
@preconcurrency import PackageDescription

class God {
	nonisolated let package = Package(
		name: "xdk",

		platforms: [
			.macOS(.v14),
			.iOS(.v17),
			.tvOS(.v17),
			.watchOS(.v10),
			.visionOS(.v1),
		],
		products: [
		],
		dependencies: [
			.package(url: "https://github.com/swiftlang/swift-testing.git", branch: "main"),
		],
		targets: [

		]
	)

	let mainTarget = Target.target(
		name: "XDKModule",
		path: "./Sources/XDKModule"
	)

	func complete() {
		self.package.targets.append(self.mainTarget)
	}
}

let god = God()


let swiftLogs = Git(module: "Logging", version: "1.6.1", url: "https://github.com/apple/swift-log.git").apply(god)
let awssdk = Git(module: "AWS", version: "1.0.32", url: "https://github.com/awslabs/aws-sdk-swift.git").apply(god)
let swiftErr = Git(module: "Err", version: "0.5.0", url: "https://github.com/walteh/swift-err.git").apply(god)
// let swiftErr = TmpLocal(module: "Err", url: "../../swift-err").apply(god)
let swiftXid = Git(module: "xid", version: "0.2.1", url: "https://github.com/uatuko/swift-xid.git").apply(god)
let ecdsa = Git(module: "MicroDeterministicECDSA", version: "0.9.0", url: "https://github.com/walteh/micro-deterministic-ecdsa.git").apply(god)
let swiftContext = Git(module: "ServiceContextModule", version: "1.1.0", url: "https://github.com/apple/swift-service-context.git").apply(god)
let swiftBigInt = Git(module: "BigInt", version: "5.4.0", url: "https://github.com/attaswift/BigInt.git").apply(god)

let x = Local(name: "XDK").with(deps: [swiftLogs, swiftContext, swiftXid, swiftErr]).apply(god)
let byte = Local(name: "Byte").with(deps: [x, swiftErr]).apply(god)
let hex = Local(name: "Hex").with(deps: [x, byte, swiftErr]).apply(god)
let keychain = Local(name: "keychain").with(deps: [x, swiftErr]).apply(god)
let rlp = Local(name: "RLP").with(deps: [x, ecdsa, byte, hex, swiftBigInt, swiftErr]).apply(god)
let logging = Local(name: "Logging").with(deps: [x, swiftLogs, hex, swiftErr]).apply(god)
let webauthn = Local(name: "Webauthn").with(deps: [x, byte, hex, keychain, swiftErr]).apply(god)
let websocket: Local = .init(name: "Websocket").with(deps: [x, byte, hex, swiftErr]).apply(god)
let awssso = Local(name: "AWSSSO").with(deps: [x, logging, awssdk.child(module: "AWSSSO"), awssdk.child(module: "AWSSSOOIDC"), swiftErr]).apply(god)

god.complete()

protocol Dep {
	func target() -> [Target.Dependency]
}

class Git {
	var product: Package.Dependency
	let name: String
	let modules: [String]

	init(modules: [String], from: String, url: String) {
		self.name = url.split(separator: "/").last!.replacingOccurrences(of: ".git", with: "")
		self.modules = modules
		self.product = .package(url: url, .upToNextMajor(from: Version(stringLiteral: from)))
	}

	init(module: String, version: String, url: String) {
		self.name = url.split(separator: "/").last!.replacingOccurrences(of: ".git", with: "")
		self.modules = [module]
		self.product = .package(url: url, exact: Version(stringLiteral: version))
	}

	init(name: String, module: String, product: Package.Dependency) {
		self.name = name
		self.modules = [module]
		self.product = product
	}

	init(module: String, from: String, url: String) {
		self.name = url.split(separator: "/").last!.replacingOccurrences(of: ".git", with: "")
		self.modules = [module]
		self.product = .package(url: url, .upToNextMajor(from: Version(stringLiteral: from)))
	}

	func child(module: String) -> Git {
		Git(name: self.name, module: module, product: self.product)
	}

	func apply(_ god: God) -> Self {
		god.package.dependencies.append(self.product)
		return self
	}
}

class TmpLocal {
	var product: Package.Dependency
	let name: String
	let modules: [String]

	init(module: String, url: String) {
		self.name = url.split(separator: "/").last!.replacingOccurrences(of: ".git", with: "")
		self.modules = [module]
		self.product = .package(path: url)
	}

	func apply(_ god: God) -> Self {
		god.package.dependencies.append(self.product)
		return self
	}
}

extension TmpLocal: Dep {
	func target() -> [Target.Dependency] {
		self.modules.map {
			.product(name: $0, package: self.name)
		}
	}
}

extension Git: Dep {
	func target() -> [Target.Dependency] {
		self.modules.map {
			.product(name: $0, package: self.name)
		}
	}
}

class Local {
	var packageFolder: String = "./Sources/Packages/"

	var name: String
	var hasC: Bool = false
	var subfolders: [Dep] = []

	func module() -> String {
		if self.name.starts(with: "XDK") {
			return self.name
		}
		return "XDK\(self.camel())"
	}

	func camel() -> String {
		"\(self.name.prefix(1).uppercased() + self.name.dropFirst())"
	}

	func with(c: Bool) -> Self {
		self.hasC = c
		return self
	}

	func with(deps: [Dep]) -> Self {
		self.subfolders = deps
		return self
	}

	func with(packageFolder: String) -> Self {
		self.packageFolder = packageFolder
		return self
	}

	init(name: String) {
		self.name = name
	}

	// @MainActor
	func apply(_ god: God) -> Self {
		god.package.products += [
			.library(name: self.module(), targets: [self.module()]),
		]

		if self.hasC {
			god.package.targets += [
				.target(
					name: "\(self.module())C",
					path: "\(self.packageFolder)\(self.name.lowercased())/c"
				),
			]
			self.subfolders += [Local(name: "\(self.camel())C")]
		}

		god.package.targets += [
			.target(
				name: self.module(),
				dependencies: self.subfolders.flatMap { $0.target() },
				path: "\(self.packageFolder)\(self.name.lowercased())/swift"
				// swiftSettings: [
				// 	.swiftLanguageVersion(.v6),
				// ]
			),
		]

		god.package.targets += [
			.testTarget(
				name: "\(self.module())Tests",
				dependencies: [.byName(name: self.module()), .product(name: "Testing", package: "swift-testing")],
				path: "\(self.packageFolder)\(self.name.lowercased())/tests"

				// swiftSettings: [
				// 	.swiftLanguageVersion(.v6),
				// ]
			),
		]

		god.mainTarget.dependencies.append(.byName(name: self.module()))

		return self
	}
}

extension Local: Dep {
	func target() -> [Target.Dependency] {
		[.byName(name: self.module())]
	}
}

