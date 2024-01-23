//
//  Api.swift
//
//
//  Created by walter on 3/5/23.
//

import Foundation
import StoreKit

public protocol MtxAPIProtocol {
	func Purchase(transaction id: String) async throws -> Bool
	func addToQueue()
	func getStoreFront()
	func getProducts()
}

public protocol StoreKitAPIProtocol: SKProductsRequestDelegate, SKPaymentTransactionObserver {}

public enum mtx {
	public typealias API = MtxAPIProtocol
	public enum storekit {
		public typealias API = StoreKitAPIProtocol
	}
}
