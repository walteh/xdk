//
//  Result.swift
//
//
//  Created by walter on 1/22/24.
//

import Foundation

public extension Result where Failure == Swift.Error {
	init(_ body: borrowing @escaping () async throws(Failure) -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async {
		do {
			self = try await .success(body())
		} catch {
			self = .failure(x.error("caught", root: error, __file: __file, __function: __function, __line: __line))
		}
	}

	init(_ body: borrowing @escaping () throws(Failure) -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) {
		do {
			self = try .success(body())
		} catch {
			self = .failure(x.error("caught", root: error, __file: __file, __function: __function, __line: __line))
		}
	}
}

public extension Result where Failure == Error {
	static func X(_ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> Result<Success, Failure> {
		return Result { try body() }.mapError { err in
			let err = x.error("caught", root: err, __file: __file, __function: __function, __line: __line)
			return err
		}
	}

	static func X(_ body: @escaping () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Result<Success, Failure> {
		do {
			let result = try await body()
			return .success(result)
		} catch {
			let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
			return .failure(err)
		}
	}

	// static func X(_ body: @escaping () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Result<Success, Failure> {
	// 	do {
	// 		let result = try await body()
	// 		return .success(result)
	// 	} catch {
	// 		let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
	// 		return .failure(err)
	// 	}
	// }
}

// public extension Result where Failure == Error, Success == Void {
// 	static func X(_ body: @escaping () throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) -> Result<Success, Failure> {
// 		do {
// 			try body()
// 			return .success(())
// 		} catch {
// 			let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
// 			return .failure(err)
// 		}
// 	}

// 	// static func X(_ body: @escaping @Sendable () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Result<Success, Failure> {
// 	// 	do {
// 	// 		try await body()
// 	// 		return .success(())
// 	// 	} catch {
// 	// 		let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
// 	// 		return .failure(err)
// 	// 	}
// 	// }

// 	static func X(_ body: @escaping () async throws -> Success, __file: String = #fileID, __function: String = #function, __line: UInt = #line) async -> Result<Success, Failure> {
// 		do {
// 			try await body()
// 			return .success(())
// 		} catch {
// 			let err = x.error("caught", root: error, __file: __file, __function: __function, __line: __line)
// 			return .failure(err)
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

// public extension Result {
// 	func to(_ err: inout Error?) -> (Success?) {
// 		return self.err(&err)
// 	}

// 	func err(_ err: inout Error?) -> (Success?) {
// 		switch self {
// 		case let .success(value):
// 			return value
// 		case let .failure(error):
// 			err = error
// 			return nil
// 		}
// 	}
// }
