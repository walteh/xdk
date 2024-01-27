
import Logging
import ServiceContextModule

public typealias Context = ServiceContext
public typealias ContextKey = ServiceContextKey

@inlinable public func GetContext() -> Context {
	return Context.current ?? Context.TODO("you should set a context")
}

// create a context key
// public protocol ContextKey<T> {
// 	associatedtype T

// 	var defaultValue: T { get }

// 	// public let rawValue: String

// 	// // fileprivate is so that only the Context class can create a key
// 	// private init(_ value: T.Type) {
// 	// 	self.rawValue = "\(value.self)"
// 	// }
// }

// // create a context

// public class Context {
// 	private var storage: [String: Any] = [:]

// 	private let parent: Context?

// 	public init(parent: Context? = nil) {
// 		self.parent = parent
// 	}

// 	public func get<T>(_ key: some ContextKey<T>) -> T {
// 		// we can force unwrap here because we know that the key is in the storage
// 		guard let value = self.storage["\(key)"] as? T else {
// 			if let parent = self.parent {
// 				return parent.get(key)
// 			}
// 			return key.defaultValue
// 		}
// 		return value
// 	}

// 	public func set<T>(_ key: any ContextKey<T>.Type, _ value: T) {
// 		self.storage["\(key)"] = value
// 	}

// 	public func clear() {
// 		self.storage = [:]
// 	}

// 	public func child() -> Context {
// 		return Context(parent: self)
// 	}
// }
