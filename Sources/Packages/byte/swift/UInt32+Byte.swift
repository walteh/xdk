//
//  File.swift
//
//
//  Created by walter on 3/4/23.
//

import Foundation

public extension UInt32 {
	var byteArrayLittleEndian: [UInt8] {
		var preres = self.byteArrayLittleEndianRaw

		while preres.first == 0 { preres.removeFirst() }

		return preres
	}

	var byteArrayLittleEndianRaw: [UInt8] {
		let r = [
			UInt8((self & 0xFF00_0000) >> 24),
			UInt8((self & 0x00FF_0000) >> 16),
			UInt8((self & 0x0000_FF00) >> 8),
			UInt8(self & 0x0000_00FF),
		]

		return r
	}
}
