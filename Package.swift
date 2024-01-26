// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
	name: "xdk"
)

let swiftLogs = Folder(product: .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"), name: "Logging", packageName: "swift-log").apply()
let swiftAtomics = Folder(product: .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"), name: "Atomics", packageName: "swift-atomics").apply()
let awssdk = Folder(product: .package(url: "https://github.com/awslabs/aws-sdk-swift", exact: "0.34.0"), name: "AWS", packageName: "aws-sdk-swift").apply()
let swiftXid = Folder(product: .package(url: "https://github.com/uatuko/swift-xid.git", exact: "0.2.1"), name: "xid", packageName: "swift-xid").apply()

let x = Folder(local: "X", hasC: false, deps: [swiftLogs]).apply()
let byte = Folder(local: "Byte", hasC: false, deps: [x]).apply()
let hex = Folder(local: "Hex", hasC: false, deps: [x, byte]).apply()
let ecdsa = Folder(local: "ECDSA", hasC: true, deps: [x, hex]).apply()
let keychain = Folder(local: "keychain", hasC: false, deps: [x]).apply()
let xid = Folder(local: "XID", hasC: false, deps: [x, swiftXid]).apply()
let big = Folder(local: "Big", hasC: false, deps: [x]).apply()
let websocket = Folder(local: "WebSocket", hasC: false, deps: [x, byte]).apply()
let mtx = Folder(local: "MTX", hasC: false, deps: [x, hex]).apply()
let rlp = Folder(local: "RLP", hasC: false, deps: [x, ecdsa, byte, hex, big]).apply()
let logging = Folder(local: "Logging", hasC: false, deps: [x, swiftLogs, hex]).apply()
let appsession = Folder(local: "AppSession", hasC: false, deps: [x, keychain, xid]).apply()
let moc = Folder(local: "MOC", hasC: false, deps: [x, keychain]).apply()
// let mqtt = Folder(local: "MQTT", hasC: false, deps: [x, byte, appsession]).apply()
let webauthn = Folder(local: "Webauthn", hasC: false, deps: [x, ecdsa, byte, hex, big, keychain, appsession]).apply()
let awssso = Folder(local: "AWSSSO", hasC: false, deps: [x, awssdk.with(name: "AWSSSO"), awssdk.with(name: "AWSSSOOIDC")]).apply()

func complete() {
	package.targets.append(mainTarget)
}

class Folder {
	let PACKAGE_ROOT = "./Sources/Packages/"

	var dummy: Package.Dependency?
	var rawName: String

	var packageName: String = "xdk"
	var hasC: Bool
	var subfolders: [Folder] = []

	func name() -> String {
		return "XDK\(self.camel())"
	}

	func camel() -> String {
		return "\(self.rawName.prefix(1).uppercased() + self.rawName.dropFirst())"
	}

	func with(name: String) -> Folder {
		if self.dummy != nil {
			return Folder(product: self.dummy!, name: name, packageName: self.packageName)
		}

		return Folder(local: name, hasC: self.hasC, deps: self.subfolders)
	}

	init(local: String, hasC: Bool = false, deps: [Folder] = []) {
		self.rawName = local
		self.hasC = hasC
		self.subfolders = deps
	}

	convenience init(product: Package.Dependency, name: String, packageName: String) {
		self.init(local: name, hasC: false, deps: [])
		self.dummy = product
		self.packageName = packageName
	}

	func apply() -> Self {
		if self.dummy != nil {
			package.dependencies.append(self.dummy!)
			return self
		}

		package.products += [
			.library(name: self.name(), targets: [self.name()]),
		]

		if self.hasC {
			package.targets += [
				.target(
					name: "\(self.name())C",
					path: "\(self.PACKAGE_ROOT)\(self.rawName.lowercased())/c"
				),
			]
			self.subfolders += [Folder(local: "\(self.camel())C", hasC: false, deps: [])]
		}
		let fulldeps: [Target.Dependency] = self.subfolders.map { $0.dummy != nil ? .product(name: $0.rawName, package: $0.packageName) : .byName(name: $0.name()) }
		package.targets += [
			.target(
				name: self.name(),
				dependencies: fulldeps,
				path: "\(self.PACKAGE_ROOT)\(self.rawName.lowercased())/swift"
			),
		]

		package.targets += [
			.testTarget(
				name: "\(self.name())Tests",
				dependencies: [.byName(name: self.name())],
				path: "\(self.PACKAGE_ROOT)\(self.rawName.lowercased())/tests"
			),
		]
		mainTarget.dependencies.append(.byName(name: self.name()))

		return self
	}
}
