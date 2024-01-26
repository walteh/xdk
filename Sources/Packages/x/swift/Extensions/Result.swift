//
//  Result.swift
//
//
//  Created by walter on 1/22/24.
//

import Foundation

public extension Result where Failure == Error {
	static func X(addContext: (XDKX.LogEvent) -> XDKX.LogEvent = { $0 }, message: String = "caught", __file: String = #fileID, __function: String = #function, __line: UInt = #line, catching body: @escaping () throws -> Success) -> Result<Success, Failure> {
		return Result { try body() }.mapError { err in
			let err = x.error(message, root: err, __file: __file, __function: __function, __line: __line).event(addContext)
			return err
		}
	}

	static func X(addContext: (XDKX.LogEvent) -> XDKX.LogEvent = { $0 }, message: String = "caught", __file: String = #fileID, __function: String = #function, __line: UInt = #line, catching body: @escaping @Sendable () async throws -> Success) async -> Result<Success, Failure> {
		do {
			let result = try await body()
			return .success(result)
		} catch {
			let err = x.error(message, root: error, __file: __file, __function: __function, __line: __line).event(addContext)
			return .failure(err)
		}
	}

	static func X(addContext: (XDKX.LogEvent) -> XDKX.LogEvent = { $0 }, message: String = "caught", __file: String = #fileID, __function: String = #function, __line: UInt = #line, catching body: @escaping () throws -> Void) -> Result<Void, Failure> {
		do {
			try body()
			return .success(())
		} catch {
			let err = x.error(message, root: error, __file: __file, __function: __function, __line: __line).event(addContext)
			return .failure(err)
		}
	}

	static func X(addContext: (XDKX.LogEvent) -> XDKX.LogEvent = { $0 }, message: String = "caught", __file: String = #fileID, __function: String = #function, __line: UInt = #line, catching body: @escaping @Sendable () async throws -> Void) async -> Result<Void, Failure> {
		do {
			try await body()
			return .success(())
		} catch {
			let err = x.error(message, root: error, __file: __file, __function: __function, __line: __line).event(addContext)
			return .failure(err)
		}
	}
}

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
	func validate() -> (success: Success, error: Failure?) {
		switch self {
		case let .success(value):
			return (value, nil)
		case let .failure(error):
			let su = unsafeBitCast(Success.self, to: Success.self)
			return (su, error)
		}
	}
}
