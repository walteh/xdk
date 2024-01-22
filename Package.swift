// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "xdk",
	platforms: [
				.macOS(.v14),
				.iOS(.v17),
				.tvOS(.v17),
				.watchOS(.v10)
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

let x = Folder(local: "x", hasC: false, deps: [swiftLogs]).apply()
let byte = Folder(local: "byte", hasC: false, deps: [x]).apply()
let hex = Folder(local: "hex", hasC: false, deps: [x, byte]).apply()
let ecdsa = Folder(local: "ecdsa", hasC: true, deps: [x, hex]).apply()
let keychain = Folder(local: "keychain", hasC: false, deps: [x]).apply()
let xid = Folder(local: "xid", hasC: false, deps: [x, swiftAtomics]).apply()
let big = Folder(local: "big", hasC: false, deps: [x]).apply()
let websocket = Folder(local: "websocket", hasC: false, deps: [x, byte]).apply()
let mtx = Folder(local: "mtx", hasC: false, deps: [x]).apply()
let rlp = Folder(local: "rlp", hasC: false, deps: [x, ecdsa, byte, hex, big]).apply()
let logging = Folder(local: "logging", hasC: false, deps: [x, swiftLogs]).apply()
let session = Folder(local: "session", hasC: false, deps: [x, keychain, xid]).apply()
let moc = Folder(local: "moc", hasC: false, deps: [x]).apply()
let mqtt = Folder(local: "mqtt", hasC: false, deps: [x, byte, session]).apply()
let webauthn = Folder(local: "webauthn", hasC: false, deps: [x, ecdsa, byte, hex, big, keychain]).apply()

func complete() {
	package.targets.append(mainTarget)
}

class Folder {
	var dummy: Package.Dependency?
	let name: String
	var packageName: String = "xdk"
	var hasC: Bool
	var subfolders: [Folder] = []

	init(local: String, hasC: Bool = false, deps: [Folder] = []) {
		name = local
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
			.library(name: name, targets: [name]),
		]
		let testName = "\(name)Tests"
		package.targets += [
			.target(
				name: name,
				dependencies: subfolders.map { $0.dummy != nil ? .product(name: $0.name, package: $0.packageName) : .byName(name: $0.name) },
				path: "./Sources/Packages/\(name)/swift"
			),
		]
		if hasC {
			package.targets += [
				.target(
					name: "\(name)/c",
					path: "./Sources/Packages/\(name)/c"
				),
			]
		}
		package.targets += [
			.testTarget(
				name: "\(testName)",
				dependencies: [.byName(name: name)],
				path: "./Sources/Packages/\(name)/tests"
			),
		]
		mainTarget.dependencies.append(.byName(name: name))

		return self
	}
}
