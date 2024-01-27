
import Foundation

public protocol StorageAPI {
	func version() -> String
	func read(ctx: Context, unsafe: String) -> Result<Data?, Error>
	func write(ctx: Context, unsafe: String, overwriting: Bool, as value: Data) -> Result<Void, Error>
}

func Read<T>(ctx: Context, using storageAPI: StorageAPI, _: T.Type) -> Result<T?, Error> where T: NSObject, T: NSSecureCoding {
	var err: Error? = nil

	let storageKey = "\(T.description())_\(storageAPI.version())"

	guard let data = storageAPI.read(ctx: ctx, unsafe: storageKey).to(&err) else {
		return .failure(x.error("failed to read object", root: err).info("storageKey", storageKey))
	}

	guard let data else { return .success(nil) }

	return Result.X {
		try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
	}
}

func Write<T>(ctx: Context, using storageAPI: StorageAPI, _ object: T, overwrite: Bool = true) -> Result<Void, Error> where T: NSObject, T: NSSecureCoding {
	var err: Error? = nil

	let storageKey = "\(T.description())_\(storageAPI.version())"

	guard let resp = Result.X({ try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) }).to(&err) else {
		return .failure(x.error("failed to archive object", root: err).info("storageKey", storageKey))
	}

	guard let _ = storageAPI.write(ctx: ctx, unsafe: storageKey, overwriting: overwrite, as: resp).to(&err) else {
		return .failure(x.error("failed to write object", root: err).info("storageKey", storageKey))
	}

	return .success(())
}
