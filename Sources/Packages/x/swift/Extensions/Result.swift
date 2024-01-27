//
//  Result.swift
//
//
//  Created by walter on 1/22/24.
//

import Foundation

public extension Result where Failure == Error {
	static func X(_ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> Result<Success, Failure> {
		return Result { try body() }.mapError { err in
			let err = x.error("caught", root: err, __file: __file, __function: __function, __line: __line)
			return err
		}
	}

	static func X(_ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Result<Success, Failure> {
		do {
			let result = try await body()
			return .success(result)
		} catch {
			let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
			return .failure(err)
		}
	}
}

public extension Result where Failure == Error, Success == Void {
	static func X(_ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> Result<Success, Failure> {
		do {
			try body()
			return .success(())
		} catch {
			let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
			return .failure(err)
		}
	}

	static func X(_ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Result<Success, Failure> {
		do {
			try await body()
			return .success(())
		} catch {
			let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
			return .failure(err)
		}
	}
}

// public extension Result where Failure == Error {
// 	static func X(catch: inout Error?, _ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> Success? {
// 		return Result.X(body, __file: __file, __function: __function, __line: __line).to(&`catch`)
// 	}

// 	static func X(catch: inout Error?, _ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Success? {
// 		return await Result.X(body, __file: __file, __function: __function, __line: __line).to(&`catch`)
// 	}
// }

// public extension Result where Failure == Error, Success == Void {
// 	static func X(catch: inout Error?, _ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> Success? {
// 		return Result.X(body, __file: __file, __function: __function, __line: __line).to(&`catch`)
// 	}

// 	static func X(catch: inout Error?, _ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Success? {
// 		return await Result.X(body, __file: __file, __function: __function, __line: __line).to(&`catch`)
// 	}
// }

// public class Res2<Success> {
// 	typealias _Result = Result<Success, Swift.Error>

// 	let line: UInt
// 	let file: String
// 	let function: String

// 	let result: _Result

// 	private init(_ result: _Result, errptr: inout Error?, __file: String, __function: String, __line: UInt) {
// 		self.result = result
// 		self.line = __line
// 		self.file = __file
// 		self.function = __function

// 		if let err = result.error, errptr == nil {
// 			errptr = err
// 		}
// 	}

// 	convenience init(_ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) {
// 		do {
// 			let result = try body()
// 			self.init(.success(result), __file: __file, __function: __function, __line: __line)
// 		} catch {
// 			self.init(.failure(error), __file: __file, __function: __function, __line: __line)
// 		}
// 	}

// 	convenience init(_ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async {
// 		do {
// 			let result = try await body()
// 			self.init(.success(result), __file: __file, __function: __function, __line: __line)
// 		} catch {
// 			self.init(.failure(error), __file: __file, __function: __function, __line: __line)
// 		}
// 	}
// }

// extension Res2 where Success == Void {
// 	convenience init(_ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) {
// 		do {
// 			try body()
// 			self.init(.success(()), __file: __file, __function: __function, __line: __line)
// 		} catch {
// 			self.init(.failure(error), __file: __file, __function: __function, __line: __line)
// 		}
// 	}

// 	convenience init(_ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async {
// 		do {
// 			try await body()
// 			self.init(.success(()), __file: __file, __function: __function, __line: __line)
// 		} catch {
// 			self.init(.failure(error), __file: __file, __function: __function, __line: __line)
// 		}
// 	}
// }

public extension Result {
	// Extract the value if it's a success
	var value: Success? {
		switch self {
		case let .success(value):
			return value
		case .failure:
			return nil
		}
	}

	// Extract the error if it's a failure
	var error: Failure? {
		switch self {
		case .success:
			return nil
		case let .failure(error):
			return error
		}
	}
}

public extension Result {
	func to(_ e: inout Error?) -> (Success?) {
		switch self {
		case let .success(value):
			return value
		case let .failure(error):
			e = error
			return nil
		}
	}
}
