import XCTest
@testable import XDKXID

final class XIDTests: XCTestCase {
	func testXIDNext() {
		let n = 100
		var ids: [XDKXID.XID] = []

		// Generate n ids
		for _ in 0 ..< n {
			ids.append(XDKXID.XID.build())
		}

		for i in 1 ..< n {
			let previous = ids[i - 1]
			let current = ids[i]

			// Test for uniqueness among all other generated ids
			for (n, id) in ids.enumerated() {
				if n == i {
					continue
				}

				XCTAssertNotEqual(current, id)
			}
//
//			// Check that timestamp was incremented and is within 30 seconds of the previous one
			let t = current.time().distance(to: previous.time())
			XCTAssertFalse(t < 0)
			XCTAssertFalse(t > 30)

			// Check that machine ids are the same
			XCTAssertEqual(current.machineID(), previous.machineID())

			// Check that pids are the same
			XCTAssertEqual(current.pid(), previous.pid())

			// Test for proper increment
			let diff = current.counter() - previous.counter()
			XCTAssertEqual(diff, 1)
		}
	}
}
