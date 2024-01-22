
public enum big {
	public struct Int {
		/// The absolute value of this integer.
		public var magnitude: big.UInt

		/// True iff the value of this integer is negative.
		public var sign: Sign
	}

	public struct UInt {
		var kind: Kind // Internal for testing only
		var storage: [Word] // Internal for testing only; stored separately to prevent COW copies
	}
}

public extension String {
	func hexToBigUInt() -> big.UInt { big.UInt(replacingOccurrences(of: "0x", with: ""), radix: 16) ?? big.UInt(0) }
	func hexToBigInt() -> big.Int { big.Int(replacingOccurrences(of: "0x", with: ""), radix: 16) ?? big.Int(0) }
}
