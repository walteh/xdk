import CryptoKit
import Foundation

import Atomics

#if canImport(UIKit)
	import UIKit
#endif

public enum xid {
	private static var buf = XIDManager()

	public static func New() -> xid.XID {
		buf.next()
	}

	public static func NewXID() -> String {
		String(describing: buf.next())
	}

	public static func NewXID(bytes: Data) throws -> xid.XID {
		if bytes.count != 12 {
			throw XIDError.invalidID
		}

		return xid.XID(_bytes: bytes)
	}

	public static func NewXID(from: Data) throws -> xid.XID {
		try xid.XID(from: from)
	}

	public static func NewXID(from: String) throws -> xid.XID {
		try xid.XID(from: from)
	}
}

struct XIDManager {
	private(set) static var counter: ManagedAtomic<Int32> = {
		var i: Int32 = 0
		let status = withUnsafeMutableBytes(of: &i) { ptr in
			SecRandomCopyBytes(kSecRandomDefault, ptr.count, ptr.baseAddress!)
		}

		if status != errSecSuccess {
			i = Int32.random(in: Int32.min ... Int32.max)
		}

		return ManagedAtomic<Int32>(i)
	}()

	private(set) lazy var mid: Data = machineID()

	private(set) lazy var pid: Data = processID()

	public init() {}

	public mutating func next() -> xid.XID {
		var bytes = Data(repeating: 0x00, count: 12)

		// Timestamp, 4 bytes (big endian)
		let ts = timestamp()
		bytes[0] = ts[0]
		bytes[1] = ts[1]
		bytes[2] = ts[2]
		bytes[3] = ts[3]

		// Machine ID, 3 bytes
		bytes[4] = mid[0]
		bytes[5] = mid[1]
		bytes[6] = mid[2]

		// Process ID, 2 bytes (specs don't specify endianness, use big endian)
		bytes[7] = pid[0]
		bytes[8] = pid[1]

		// Increment, 3 bytes (big endian)
		let i = XIDManager.counter.wrappingIncrementThenLoad(ordering: .relaxed)
		bytes[9] = UInt8((i & 0xFF0000) >> 16)
		bytes[10] = UInt8((i & 0x00FF00) >> 8)
		bytes[11] = UInt8(i & 0x0000FF)

		return xid.XID(_bytes: bytes)
	}

	func machineID() -> Data {
		let ptr = UnsafeMutablePointer<uuid_t>.allocate(capacity: 1)
		defer {
			ptr.deinitialize(count: 1)
			ptr.deallocate()
		}

		#if os(macOS)
			var timeout = timespec(tv_sec: 0, tv_nsec: 500_000_000)
			gethostuuid(ptr, &timeout)
		#else
			#if canImport(UIKit)
				ptr.pointee = UIDevice.current.identifierForVendor!.uuid
			#else
				uuid_generate(ptr)
			#endif
		#endif

		let mid: Data = withUnsafeBytes(of: ptr.pointee) { bytes in
			Data(Insecure.MD5.hash(data: bytes))
		}

		return mid
	}

	func processID() -> Data {
		var pid = Int32(getpid()).bigEndian
		let data = Data(bytes: &pid, count: MemoryLayout.size(ofValue: pid))

		// Can't really fit a 4 byte `pid_t` into 2 bytes, ignore the most significant bytes
		return Data(data[2 ... 3])
	}

	func timestamp() -> Data {
		var n = UInt32(Date().timeIntervalSince1970).bigEndian
		let data = Data(bytes: &n, count: MemoryLayout.size(ofValue: n))

		return data
	}
}
