
import Foundation

public protocol StorageAPI {
	func version() -> String
	func read(unsafe: String) -> Result<Data?, Error>
	func write(unsafe: String, overwriting: Bool, as value: Data) -> Result<Void, Error>
}

// class Keyed<T>: NSObject, NSSecureCoding where T: NSObject, T: NSSecureCoding {
// 	static func keyz() -> String {
// 		return ""
// 	}

// 	let internalValue: T
// 	let key: String

// 	init(key: String, value: T) {
// 		self.key = key
// 		self.internalValue = value
// 	}

// 	public static var supportsSecureCoding: Bool { true }

// 	public required init?(coder: NSCoder) {
// 		guard let internalValue = coder.decodeObject(of: T.self, forKey: self.key) as T? else {
// 			return nil
// 		}

// 		self.internalValue = internalValue
// 		self.key = Self.keyz()
// 	}

// 	func encode(with coder: NSCoder) {
// 		coder.encode(self.internalValue, forKey: self.key)
// 	}
// }

// the  differentiator is used to allow multiple versions of the same object to be stored
public func Read<T>(using storageAPI: StorageAPI, _: T.Type, differentiator: String = "") -> Result<T?, Error> where T: NSObject, T: NSSecureCoding {
	var err: Error? = nil

	let storageKey = "\(T.description())_\(storageAPI.version())_\(differentiator)"

	guard let data = storageAPI.read(unsafe: storageKey).to(&err) else {
		return .failure(x.error("failed to read object", root: err).info("storageKey", storageKey))
	}

	guard let data else { return .success(nil) }

	return Result.X {
		try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
	}
}

public func Write<T>(using storageAPI: StorageAPI, _ object: T, overwrite: Bool = true, differentiator: String = "") -> Result<Void, Error> where T: NSObject, T: NSSecureCoding {
	var err: Error? = nil

	let storageKey = "\(T.description())_\(storageAPI.version())_\(differentiator)"

	guard let resp = Result.X({ try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) }).to(&err) else {
		return .failure(x.error("failed to archive object", root: err).info("storageKey", storageKey))
	}

	guard let _ = storageAPI.write(unsafe: storageKey, overwriting: overwrite, as: resp).to(&err) else {
		return .failure(x.error("failed to write object", root: err).info("storageKey", storageKey))
	}

	return .success(())
}

public class NoopStorage: StorageAPI {
	public func version() -> String {
		return "noop"
	}

	public func read(unsafe _: String) -> Result<Data?, Error> {
		return .success(nil)
	}

	public func write(unsafe _: String, overwriting _: Bool, as _: Data) -> Result<Void, Error> {
		return .success(())
	}

	public init() {}
}

public class InMemoryStorage: StorageAPI {
	var storage: [String: Data] = [:]

	public func version() -> String {
		return "inmemory"
	}

	public func read(unsafe key: String) -> Result<Data?, Error> {
		return .success(self.storage[key])
	}

	public func write(unsafe key: String, overwriting: Bool, as value: Data) -> Result<Void, Error> {
		if !overwriting, self.storage[key] != nil {
			return .failure(x.error("key already exists"))
		}

		self.storage[key] = value

		return .success(())
	}

	public init() {}
}
