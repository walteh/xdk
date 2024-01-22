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

let x = Folder(local: "X", hasC: false, deps: [swiftLogs]).apply()
let byte = Folder(local: "Byte", hasC: false, deps: [x]).apply()
let hex = Folder(local: "Hex", hasC: false, deps: [x, byte]).apply()
let ecdsa = Folder(local: "ECDSA", hasC: true, deps: [x, hex]).apply()
let keychain = Folder(local: "keychain", hasC: false, deps: [x]).apply()
let xid = Folder(local: "XID", hasC: false, deps: [x, swiftAtomics]).apply()
let big = Folder(local: "Big", hasC: false, deps: [x]).apply()
let websocket = Folder(local: "WebSocket", hasC: false, deps: [x, byte]).apply()
let mtx = Folder(local: "MTX", hasC: false, deps: [x, hex]).apply()
let rlp = Folder(local: "RLP", hasC: false, deps: [x, ecdsa, byte, hex, big]).apply()
let logging = Folder(local: "Logging", hasC: false, deps: [x, swiftLogs, hex]).apply()
let session = Folder(local: "Session", hasC: false, deps: [x, keychain, xid]).apply()
let moc = Folder(local: "MOC", hasC: false, deps: [x, keychain]).apply()
let mqtt = Folder(local: "MQTT", hasC: false, deps: [x, byte, session]).apply()
let webauthn = Folder(local: "Webauthn", hasC: false, deps: [x, ecdsa, byte, hex, big, keychain, session]).apply()

func complete() {
	package.targets.append(mainTarget)
}

class Folder {
	let PACKAGE_ROOT = "./Sources/Packages/"

	var dummy: Package.Dependency?
	let rawName: String

	var packageName: String = "xdk"
	var hasC: Bool
	var subfolders: [Folder] = []

	func name() -> String {
		return "XDK\(camel())"
	}

	func camel() -> String {
		return "\(rawName.prefix(1).uppercased() + rawName.dropFirst())"
	}

	init(local: String, hasC: Bool = false, deps: [Folder] = []) {
		rawName = local
		self.hasC = hasC
		subfolders = deps
	}

	convenience init(product: Package.Dependency, name: String, packageName: String) {
		self.init(local: name, hasC: false, deps: [])
		dummy = product
		self.packageName = packageName
	}

	func apply() -> Self {
		if dummy != nil {
			package.dependencies.append(dummy!)
			return self
		}

		package.products += [
			.library(name: name(), targets: [name()]),
		]

		if hasC {
			package.targets += [
				.target(
					name: "\(name())C",
					path: "\(PACKAGE_ROOT)\(rawName.lowercased())/c"
				),
			]
			subfolders += [Folder(local: "\(camel())C", hasC: false, deps: [])]
		}
		let fulldeps: [Target.Dependency] = subfolders.map { $0.dummy != nil ? .product(name: $0.rawName, package: $0.packageName) : .byName(name: $0.name()) }
		package.targets += [
			.target(
				name: name(),
				dependencies: fulldeps,
				path: "\(PACKAGE_ROOT)\(rawName.lowercased())/swift"
			),
		]

		package.targets += [
			.testTarget(
				name: "\(name())Tests",
				dependencies: [.byName(name: name())],
				path: "\(PACKAGE_ROOT)\(rawName.lowercased())/tests"
			),
		]
		mainTarget.dependencies.append(.byName(name: name()))

		return self
	}
}
