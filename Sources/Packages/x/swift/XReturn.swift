//
//  XReturn.swift
//  nugg.xyz
//
//  Created by walter on 12/6/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation

enum XReturn<T> {
	case ok(T)
	case err(x.Error)
}

func toXReturn<T>(arg: () throws -> T) -> XReturn<T> {
	do {
		let a = try arg()
		return .ok(a)
	} catch {
		return .err(x.Error.wrap(error))
	}
}
