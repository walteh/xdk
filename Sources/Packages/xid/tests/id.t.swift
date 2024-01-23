import XCTest
@testable import XDKXID

final class IDTests: XCTestCase {
	func testIDDecodable() throws {
		let data = "\"caia5ng890f0tr00hgtg\"".data(using: .utf8)!
		let decoder = JSONDecoder()
		let id = try decoder.decode(XDKXID.XID.self, from: data)

		XCTAssertEqual("caia5ng890f0tr00hgtg", String(describing: id))
	}

	func testIDEncodable() throws {
		let id = XID.build()

		let encoder = JSONEncoder()
		let data = try encoder.encode(id)

		let expected = "\"\(String(describing: id))\""
		let actual = String(data: data, encoding: .utf8)
		XCTAssertEqual(expected, actual)
	}

	func testIDInitFromDataThrow() {
		XCTAssertThrowsError(try XDKXID.XID.rebuild(raw: Data([0x78, 0x69, 0x64]))) { error in
			XCTAssertEqual(XIDError.InvalidRawDataLength(have: 3, want: 12), error as! XIDError)
		}
	}

	func testIDInitFromStringThrow() {
		XCTAssertThrowsError(try XDKXID.XID.rebuild(string: "xid")) { error in
			XCTAssertEqual(XIDError.InvalidStringLength(have: 3, want: 20), error as! XIDError)
		}

		XCTAssertThrowsError(try XDKXID.XID.rebuild(string: "caia5ng890f0tr00hgt=")) { error in
			XCTAssertEqual(XIDError.decodeValidationFailure, error as! XIDError)
		}
	}

	func testIDPartsExtraction() {
		struct Test {
			var id: XDKXID.XID
			var time: Date
			var machineID: Data
			var pid: UInt16
			var counter: Int32
		}

		let tests: [Test] = [
			Test(
				id: try! XDKXID.XID.rebuild(raw: Data([0x4D, 0x88, 0xE1, 0x5B, 0x60, 0xF4, 0x86, 0xE4, 0x28, 0x41, 0x2D, 0xC9])),
				time: Date(timeIntervalSince1970: TimeInterval(1_300_816_219)),
				machineID: Data([0x60, 0xF4, 0x86]),
				pid: 0xE428,
				counter: 4_271_561
			),
			Test(
				id: try! XDKXID.XID.rebuild(raw: Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])),
				time: Date(timeIntervalSince1970: TimeInterval(0)),
				machineID: Data([0x00, 0x00, 0x00]),
				pid: 0x0000,
				counter: 0
			),
			Test(
				id: try! XDKXID.XID.rebuild(raw: Data([0x00, 0x00, 0x00, 0x00, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x00, 0x00, 0x01])),
				time: Date(timeIntervalSince1970: TimeInterval(0)),
				machineID: Data([0xAA, 0xBB, 0xCC]),
				pid: 0xDDEE,
				counter: 1
			),
		]

		for test in tests {
			XCTAssertEqual(test.time, test.id.time())
			XCTAssertEqual(test.machineID, test.id.machineID())
			XCTAssertEqual(test.pid, test.id.pid())
			XCTAssertEqual(test.counter, test.id.counter())
		}
	}

	func testIDString() throws {
		let bytes: [UInt8] = [0x4D, 0x88, 0xE1, 0x5B, 0x60, 0xF4, 0x86, 0xE4, 0x28, 0x41, 0x2D, 0xC9]
		let id = try XDKXID.XID.rebuild(raw: Data(bytes))

		XCTAssertEqual("9m4e2mr0ui3e8a215n4g", String(describing: id))
	}
}
