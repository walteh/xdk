//
//  Byte+Control.swift
//  nugg.xyz
//
//  Created by walter on 11/18/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

/// Adds control character conveniences to `Byte`.
public extension Byte {
	/// Returns whether or not the given byte can be considered UTF8 whitespace
	var isWhitespace: Bool {
		return self == .space || self == .newLine || self == .carriageReturn || self == .horizontalTab
	}

	/// '\t'
	static let horizontalTab: Byte = 0x9

	/// '\n'
	static let newLine: Byte = 0xA

	/// '\r'
	static let carriageReturn: Byte = 0xD

	/// ' '
	static let space: Byte = 0x20

	/// !
	static let exclamation: Byte = 0x21

	/// "
	static let quote: Byte = 0x22

	/// #
	static let numberSign: Byte = 0x23

	/// $
	static let dollar: Byte = 0x24

	/// %
	static let percent: Byte = 0x25

	/// &
	static let ampersand: Byte = 0x26

	/// '
	static let apostrophe: Byte = 0x27

	/// (
	static let leftParenthesis: Byte = 0x28

	/// )
	static let rightParenthesis: Byte = 0x29

	/// *
	static let asterisk: Byte = 0x2A

	/// +
	static let plus: Byte = 0x2B

	/// ,
	static let comma: Byte = 0x2C

	/// -
	static let hyphen: Byte = 0x2D

	/// .
	static let period: Byte = 0x2E

	/// /
	static let forwardSlash: Byte = 0x2F

	/// \
	static let backSlash: Byte = 0x5C

	/// :
	static let colon: Byte = 0x3A

	/// ;
	static let semicolon: Byte = 0x3B

	/// =
	static let equals: Byte = 0x3D

	/// ?
	static let questionMark: Byte = 0x3F

	/// @
	static let at: Byte = 0x40

	/// [
	static let leftSquareBracket: Byte = 0x5B

	/// ]
	static let rightSquareBracket: Byte = 0x5D

	/// ^
	static let caret: Byte = 0x5E

	/// _
	static let underscore: Byte = 0x5F

	/// `
	static let backtick: Byte = 0x60

	/// ~
	static let tilde: Byte = 0x7E

	/// {
	static let leftCurlyBracket: Byte = 0x7B

	/// }
	static let rightCurlyBracket: Byte = 0x7D

	/// <
	static let lessThan: Byte = 0x3C

	/// >
	static let greaterThan: Byte = 0x3E

	/// |
	static let pipe: Byte = 0x7C
}

public extension Byte {
	/// Defines the `crlf` used to denote line breaks in HTTP and many other formatters
	static let crlf: Bytes = [
		.carriageReturn,
		.newLine,
	]
}
