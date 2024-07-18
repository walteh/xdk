import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct AutoReturnErrorReturnMacro: ExpressionMacro {
	public static func expansion(
		of node: some FreestandingMacroExpansionSyntax,
		in _: some MacroExpansionContext
	) -> ExprSyntax {
		// guard let a1 = node.arguments.first?.expression else {
		//     fatalError("compiler bug: the macro does not have any arguments")
		// }

		print(node)

		let expression = node.arguments.first?.expression
		var argument = node.trailingClosure
		if argument == nil {
			argument = node.additionalTrailingClosures.first?.closure
		}

		if argument == nil {
			if expression != nil {
				return """
				Result(\(expression)).to(&err) else { return .failure(result.error(root: err)) }
				"""
			}
		}

		if argument == nil {
			fatalError("compiler bug: the macro does not have any closure arguments")
		}

		return """
		Result(\(argument)).to(&err) else { return .failure(result.error(root: err)) }
		"""
	}
}

@main
struct XDKMacrosPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		AutoReturnErrorReturnMacro.self,
	]
}
