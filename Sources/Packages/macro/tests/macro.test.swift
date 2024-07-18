import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(XDKMacroMacros)
	import XDKMacroMacros
#endif

final class MyMacroTests: XCTestCase {
	func testMacro() throws {
		#if canImport(XDKMacroMacros)
			let macros: [String: Macro.Type] = [
				"autoreturn": AutoReturnErrorReturnMacro.self,
			]
			assertMacroExpansion(
				"""
				guard let hi = #autoreturn { try await wazzup() }
				""",
				expandedSource: """
				guard let hi = Result { try await wazzup() } else { return .failure(result.error(root: err)) }
				""",
				macros: macros
			)
		#else
			throw XCTSkip("macros are only supported when running tests for the host platform")
		#endif
	}
}
