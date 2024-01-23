
import XCTest
@testable import XDKXID

final class Tests: XCTestCase {
	func testJSONDecode() throws {
		struct User: Decodable {
			var id: XDKXID.XID
			var name: String
		}

		let data = """
		{
		  "id": "cajj5ctbutokmmm2jdsg",
		  "name": "user:testJsonDecode"
		}
		""".data(using: .utf8)!

		let decoder = JSONDecoder()
		let user = try decoder.decode(User.self, from: data)

		XCTAssertEqual("cajj5ctbutokmmm2jdsg", String(describing: user.id))
	}

	func testJSONEncode() throws {
		struct User: Encodable {
			var id: XDKXID.XID
			var name: String
		}

		let user = User(id: XDKXID.XID.build(), name: "user:testJsonEncode")

		let encoder = JSONEncoder()
		let data = try encoder.encode(user)

		print(String(data: data, encoding: .utf8)!)
		XCTAssertEqual(
			"{\"id\":\"\(user.id)\",\"name\":\"user:testJsonEncode\"}",
			String(data: data, encoding: .utf8)
		)
	}

	func testNewXIDFromBytes() throws {
		let id = try XID.rebuild(raw: Data([0x62, 0xA7, 0x28, 0x66, 0xAB, 0xF7, 0x71, 0x46, 0x09, 0xA4, 0xA3, 0x55]))

		XCTAssertEqual("cajigplbutokc2d4kdag", String(describing: id))
	}

//	func testNewXIDFromData() throws {
//		let actual = try XID.rebuild(raw: "9m4e2mr0ui3e8a215n4g".data(using: .utf8)!)
//		let expected = try XID.rebuild(raw: Data([0x4D, 0x88, 0xE1, 0x5B, 0x60, 0xF4, 0x86, 0xE4, 0x28, 0x41, 0x2D, 0xC9]))
//
//		XCTAssertEqual(expected, actual)
//	}

	func testNewXIDFromString() throws {
		let actual = try XID.rebuild(string: "9m4e2mr0ui3e8a215n4g")
		let expected = try XID.rebuild(raw: Data([0x4D, 0x88, 0xE1, 0x5B, 0x60, 0xF4, 0x86, 0xE4, 0x28, 0x41, 0x2D, 0xC9]))

		XCTAssertEqual(expected, actual)
	}
}
