// https://gist.github.com/ppth0608/edaf9d4e2b1932a72f98688a346805f5

import Foundation

public extension TimeInterval {
	func seconds() -> Int {
		return Int(self.rounded())
	}

	func milliseconds() -> Int {
		return Int(self * 1000)
	}
}
