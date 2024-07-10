
import Foundation

public protocol StorageAPI: Sendable {
	func version() -> String
	func read(unsafe: String) -> Result<Data?, Error>
	func write(unsafe: String, overwriting: Bool, as value: Data) -> Result<Void, Error>
	func delete(unsafe: String) -> Result<Void, Error>
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

// 	public static let supportsSecureCoding: Bool { true }

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
// public func Read<T>(using storageAPI: StorageAPI, _: T.Type, differentiator: String = "") -> Result<T?, Error> where T: NSObject, T: NSSecureCoding {
// 	var err: Error? = nil

// 	let storageKey = "\(T.description())_\(storageAPI.version())_\(differentiator)"

// 	guard let data = storageAPI.read(unsafe: storageKey).to(&err) else {
// 		return .failure(x.error("failed to read object", root: err).info("storageKey", storageKey))
// 	}

// 	guard let data else { return .success(nil) }

// 	return Result.X {
// 		try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
// 	}
// }

// public func Write<T>(using storageAPI: StorageAPI, _ object: T, overwrite: Bool = true, differentiator: String = "") -> Result<Void, Error> where T: NSObject, T: NSSecureCoding {
// 	var err: Error? = nil

// 	let storageKey = "\(T.description())_\(storageAPI.version())_\(differentiator)"

// 	guard let resp = Result.X({ try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) }).to(&err) else {
// 		return .failure(x.error("failed to archive object", root: err).info("storageKey", storageKey))
// 	}

// 	guard let _ = storageAPI.write(unsafe: storageKey, overwriting: overwrite, as: resp).to(&err) else {
// 		return .failure(x.error("failed to write object", root: err).info("storageKey", storageKey))
// 	}

// 	return .success(())
// }

public func Read<T: Codable & Sendable>(using storageAPI: StorageAPI, _: T.Type, differentiator: String = "") -> Result<T?, Error> {
	let storageKey = "\(T.self)_\(storageAPI.version())_\(differentiator)"
	var err: Error? = nil

	guard let data = storageAPI.read(unsafe: storageKey).err(&err) else {
		return .failure(x.error("failed to read object", root: err).info("storageKey", storageKey))
	}
	guard let data else { return .success(nil) }

	let decoder = JSONDecoder()
	guard let object = Result.X({ try decoder.decode(T.self, from: data) }).err(&err) else {
		return .failure(x.error("failed to decode object", root: err).info("storageKey", storageKey))
	}
	return .success(object)
}

public func Write<T: Codable & Sendable>(using storageAPI: StorageAPI, _ object: T, overwrite: Bool = true, differentiator: String = "") -> Result<Void, Error> {
	var err: Error? = nil

	let storageKey = "\(T.self)_\(storageAPI.version())_\(differentiator)"

	let encoder = JSONEncoder()
	guard let data = Result.X({ try encoder.encode(object) }).err(&err) else {
		return .failure(x.error("failed to encode object", root: err).info("storageKey", storageKey))
	}
	guard let _ = storageAPI.write(unsafe: storageKey, overwriting: overwrite, as: data).err(&err) else {
		print(err)
		return .failure(x.error("failed to write object", root: err).info("storageKey", storageKey))
	}

	return .success(())
}

public func Delete<T: Codable & Sendable>(using storageAPI: StorageAPI, _: T.Type, differentiator: String = "") -> Result<Void, Error> {
	var err: Error? = nil

	let storageKey = "\(T.self)_\(storageAPI.version())_\(differentiator)"

	guard let _ = storageAPI.delete(unsafe: storageKey).err(&err) else {
		return .failure(x.error("failed to delete object", root: err).info("storageKey", storageKey))
	}

	return .success(())
}

// public func Delete<T>(using storageAPI: StorageAPI, _: T.Type, differentiator: String = "") -> Result<Void, Error> where T: NSObject, T: NSSecureCoding {
// 	var err: Error? = nil

// 	let storageKey = "\(T.description())_\(storageAPI.version())_\(differentiator)"

// 	guard let _ = storageAPI.delete(unsafe: storageKey).to(&err) else {
// 		return .failure(x.error("failed to delete object", root: err).info("storageKey", storageKey))
// 	}

// 	return .success(())
// }

public struct NoopStorage: StorageAPI {
	public func version() -> String {
		"noop"
	}

	public func read(unsafe _: String) -> Result<Data?, Error> {
		.success(nil)
	}

	public func write(unsafe _: String, overwriting _: Bool, as _: Data) -> Result<Void, Error> {
		.success(())
	}

	public func delete(unsafe _: String) -> Result<Void, Error> {
		.success(())
	}

	public init() {}
}

public final class InMemoryStorage: StorageAPI, @unchecked Sendable {
	private var storage: [String: Data] = [:]
	private let queue = DispatchQueue(label: "com.example.inmemorystorage", attributes: .concurrent)

	public func version() -> String {
		"inmemory"
	}

	public func read(unsafe key: String) -> Result<Data?, Error> {
		var result: Result<Data?, Error>!
		self.queue.sync {
			result = .success(self.storage[key])
		}
		return result
	}

	public func write(unsafe key: String, overwriting: Bool, as value: Data) -> Result<Void, Error> {
		var result: Result<Void, Error>!
		self.queue.sync(flags: .barrier) {
			if !overwriting, self.storage[key] != nil {
				result = .failure(NSError(domain: "com.example.inmemorystorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "key already exists"]))
			} else {
				self.storage[key] = value
				result = .success(())
			}
		}
		return result
	}

	public func delete(unsafe key: String) -> Result<Void, Error> {
		var result: Result<Void, Error>!
		self.queue.sync(flags: .barrier) {
			self.storage[key] = nil
			result = .success(())
		}
		return result
	}

	public init() {}
}
