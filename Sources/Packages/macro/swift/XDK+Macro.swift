

// @attached(member) @attached(peer)
// @_documentation(visibility: private)
// public macro Suite(
//   _ traits: any SuiteTrait...
// ) = #externalMacro(module: "TestingMacros", type: "SuiteDeclarationMacro")

// @macro
// public macro autoReturnError<T>(_ expression: @autoclosure () throws -> T) -> T? = #externalMacro(module: "AutoReturnErrorMacros", type: "AutoReturnErrorMacro")

@freestanding(expression) public macro autoreturn<R>(
	// _ comment: @autoclosure () -> String? = nil,
	performing expression: @escaping () async throws -> R
) -> R = #externalMacro(module: "XDKMacroMacros", type: "AutoReturnErrorReturnMacro")
