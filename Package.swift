// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
	name: "xdk",
	platforms: [
		.macOS(.v14),
		.iOS(.v17),
		.tvOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
	],
	products: [],
	dependencies: [],
	targets: []
)

let mainTarget = Target.target(
	name: "XDKModule",
	path: "./Sources/XDKModule"
)

let swiftLogs = Git(module: "Logging", version: "1.5.4", url: "https://github.com/apple/swift-log.git").apply()
// let swiftAtomics = Git(module: "Atomics", version: "1.2.0", url: "https://github.com/apple/swift-atomics.git").apply()
let awssdk = Git(module: "AWS", version: "0.44.0", url: "https://github.com/awslabs/aws-sdk-swift.git").apply()
let swiftXid = Git(module: "xid", version: "0.2.1", url: "https://github.com/uatuko/swift-xid.git").apply()
let ecdsa = Git(module: "MicroDeterministicECDSA", version: "0.8.0", url: "https://github.com/walteh/micro-deterministic-ecdsa.git").apply()
let swiftContext = Git(module: "ServiceContextModule", version: "1.0.0", url: "https://github.com/apple/swift-service-context.git").apply()

let x = Local(name: "XDK").with(deps: [swiftLogs, swiftContext, swiftXid]).apply()
let byte = Local(name: "Byte").with(deps: [x]).apply()
let hex = Local(name: "Hex").with(deps: [x, byte]).apply()
let keychain = Local(name: "keychain").with(deps: [x]).apply()
let big = Local(name: "Big").with(deps: [x]).apply()
let websocket = Local(name: "WebSocket").with(deps: [x, byte]).apply()
let mtx = Local(name: "MTX").with(deps: [x, hex]).apply()
let rlp = Local(name: "RLP").with(deps: [x, ecdsa, byte, hex, big]).apply()
let logging = Local(name: "Logging").with(deps: [x, swiftLogs, hex]).apply()
let moc = Local(name: "MOC").with(deps: [x, keychain]).apply()
let webauthn = Local(name: "Webauthn").with(deps: [x,  byte, hex, big, keychain]).apply()
let awssso = Local(name: "AWSSSO").with(deps: [x, logging, awssdk.child(module: "AWSSSO"), awssdk.child(module: "AWSSSOOIDC")]).apply()

func complete() {
	package.targets.append(mainTarget)
}

protocol Dep {
	func target() -> Target.Dependency
}

class Git {
	var product: Package.Dependency
	let name: String
	let module: String

	init(module: String, version: String, url: String) {
		self.name = url.split(separator: "/").last!.replacingOccurrences(of: ".git", with: "")
		self.module = module
		self.product = .package(url: url, exact: Version(stringLiteral: version))
	}

	init(name: String, module: String, product: Package.Dependency) {
		self.name = name
		self.module = module
		self.product = product
	}

	func child(module: String) -> Git {
		return Git(name: self.name, module: module, product: self.product)
	}

	func apply() -> Self {
		package.dependencies.append(self.product)
		return self
	}
}

extension Git: Dep {
	func target() -> Target.Dependency {
		return .product(name: self.module, package: self.name)
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
		return "\(self.name.prefix(1).uppercased() + self.name.dropFirst())"
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

	func apply() -> Self {
		package.products += [
			.library(name: self.module(), targets: [self.module()]),
		]

		if self.hasC {
			package.targets += [
				.target(
					name: "\(self.module())C",
					path: "\(self.packageFolder)\(self.name.lowercased())/c"
				),
			]
			self.subfolders += [Local(name: "\(self.camel())C")]
		}

		package.targets += [
			.target(
				name: self.module(),
				dependencies: self.subfolders.map { $0.target() },
				path: "\(self.packageFolder)\(self.name.lowercased())/swift"
			),
		]

		package.targets += [
			.testTarget(
				name: "\(self.module())Tests",
				dependencies: [.byName(name: self.module())],
				path: "\(self.packageFolder)\(self.name.lowercased())/tests"
			),
		]

		mainTarget.dependencies.append(.byName(name: self.module()))

		return self
	}
}

extension Local: Dep {
	func target() -> Target.Dependency {
		return .byName(name: self.module())
	}
}

complete()
