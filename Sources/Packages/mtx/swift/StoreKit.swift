//
//  StoreKit.swift
//  nugg.xyz
//
//  Created by walter on 12/10/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation
import StoreKit

import XDKX

extension mtx.Client: mtx.storekit.API {
	public func addToQueue() {
		SKPaymentQueue.default().add(self)
	}

	public func getStoreFront() {
		SKCloudServiceController.requestAuthorization { status in
			if status == .authorized {
				SKCloudServiceController().requestStorefrontCountryCode { countryCode, _ in
					if let countryCode {
						print(countryCode)
					}
				}

				SKCloudServiceController().requestCapabilities(completionHandler: { x, y in
					print(x)
					print(y ?? "no error")
				})
			}
		}
	}

	public func getProducts() {
		let request = SKProductsRequest(productIdentifiers: Set(["gas"]))
		request.delegate = self
		request.start()
	}
}

extension mtx.Client: SKProductsRequestDelegate {
	public func productsRequest(_: SKProductsRequest, didReceive response: SKProductsResponse) {
		x.log(.info).msg(response.products.debugDescription)

		if !response.invalidProductIdentifiers.isEmpty {
			x.error("invalid product ids: [\(response.invalidProductIdentifiers.debugDescription)]").log()
		}

		if !response.products.isEmpty {
			x.log(.info).msg("requesting payment...")
			let payment = SKPayment(product: response.products[0])

			SKPaymentQueue.default().add(payment)
		}
	}
}

extension mtx.Client: SKPaymentTransactionObserver {
	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		x.log(.info).msg("calling updatedTransactions")

		// handle all possible errors
		// https://developer.apple.com/documentation/storekit/skpaymenttransactionobserver/1506093-paymentqueue
		for transaction in transactions {
			x.log(.info).msg(transaction.transactionIdentifier ?? "unknown")

			switch transaction.transactionState {
			case .purchasing:
				x.log(.info).msg("purchasing")
			case .deferred:

				x.log(.info).msg("deferred")
			case .failed:
				x.log(.info).msg("failed")
//				x.error(transaction.error).log()
				queue.finishTransaction(transaction)
			case .purchased:
				x.log(.info).msg("purchased")
				Task {
					do {
						_ = try await Purchase(transaction: transaction.transactionIdentifier ?? "")
						queue.finishTransaction(transaction)
					} catch {
						x.Error(error, message: "problem finishing transaction").log()
					}
				}
			case .restored:
				x.log(.info).msg("restored")
				queue.finishTransaction(transaction)
			@unknown default:
				x.log(.info).msg("unknown")
				queue.finishTransaction(transaction)
			}
//			queue.finishTransaction(transaction)
		}
	}

	public func paymentQueue(_: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
		x.log(.info).msg("removed transactions")

		// print the transactions
		for transaction in transactions {
			x.log(.info).msg(transaction.debugDescription)
		}
	}

	public func paymentQueue(_: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		x.log(.info).msg("restore failed")
		// print the error
		x.error(error).log()
	}

	public func paymentQueueRestoreCompletedTransactionsFinished(_: SKPaymentQueue) {
		x.log(.info).msg("restore finished")
	}

	public func paymentQueue(_: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
		x.log(.info).msg("should add store payment")
		// log the args
		x.log(.info).msg("payment: \(payment)")
		x.log(.info).msg("product: \(product)")
		return true
	}

	public func paymentQueue(_: SKPaymentQueue, shouldShowPrice price: NSDecimalNumber, for product: SKProduct) -> Bool {
		x.log(.info).msg("should show price")
		// log the args
		x.log(.info).msg("price: \(price)")
		x.log(.info).msg("product: \(product)")
		return true
	}

	public func paymentQueue(_: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct, withDefaultPrice price: NSDecimalNumber) -> Bool {
		x.log(.info).msg("should add store payment with default price")
		// log the args
		x.log(.info).msg("payment: \(payment)")
		x.log(.info).msg("product: \(product)")
		x.log(.info).msg("price: \(price)")
		return true
	}

	public func paymentQueue(_: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
		x.log(.info).msg("did revoke entitlements for product identifiers: \(productIdentifiers)")
	}

	public func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue) {
		x.log(.info).msg("did change storefront: \(queue)")
	}
}
