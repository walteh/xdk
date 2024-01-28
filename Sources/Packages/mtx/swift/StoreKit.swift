//
//  StoreKit.swift
//  nugg.xyz
//
//  Created by walter on 12/10/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//

import Foundation
import StoreKit

import XDK

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
		x.log(.info).send(response.products.debugDescription)

		if !response.invalidProductIdentifiers.isEmpty {
			x.log(.error).send("invalid product ids: [\(response.invalidProductIdentifiers.debugDescription)]")
		}

		if !response.products.isEmpty {
			x.log(.info).send("requesting payment...")
			let payment = SKPayment(product: response.products[0])

			SKPaymentQueue.default().add(payment)
		}
	}
}

extension mtx.Client: SKPaymentTransactionObserver {
	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		x.log(.info).send("calling updatedTransactions")

		// handle all possible errors
		// https://developer.apple.com/documentation/storekit/skpaymenttransactionobserver/1506093-paymentqueue
		for transaction in transactions {
			x.log(.info).send(transaction.transactionIdentifier ?? "unknown")

			switch transaction.transactionState {
			case .purchasing:
				x.log(.info).send("purchasing")
			case .deferred:

				x.log(.info).send("deferred")
			case .failed:
				x.log(.info).send("failed")
//				x.error(transaction.error).log()
				queue.finishTransaction(transaction)
			case .purchased:
				x.log(.info).send("purchased")
				Task {
					do {
						_ = try await Purchase(transaction: transaction.transactionIdentifier ?? "")
						queue.finishTransaction(transaction)
					} catch {
						x.log(.error).err(error).send("problem finishing transaction")
					}
				}
			case .restored:
				x.log(.info).send("restored")
				queue.finishTransaction(transaction)
			@unknown default:
				x.log(.info).send("unknown")
				queue.finishTransaction(transaction)
			}
//			queue.finishTransaction(transaction)
		}
	}

	public func paymentQueue(_: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
		x.log(.info).send("removed transactions")

		// print the transactions
		for transaction in transactions {
			x.log(.info).send(transaction.debugDescription)
		}
	}

	public func paymentQueue(_: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		x.log(.error).err(error).send("restore failed")
	}

	public func paymentQueueRestoreCompletedTransactionsFinished(_: SKPaymentQueue) {
		x.log(.info).send("restore finished")
	}

	public func paymentQueue(_: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
		x.log(.info).send("should add store payment")
		// log the args
		x.log(.info).send("payment: \(payment)")
		x.log(.info).send("product: \(product)")
		return true
	}

	public func paymentQueue(_: SKPaymentQueue, shouldShowPrice price: NSDecimalNumber, for product: SKProduct) -> Bool {
		x.log(.info).send("should show price")
		// log the args
		x.log(.info).send("price: \(price)")
		x.log(.info).send("product: \(product)")
		return true
	}

	public func paymentQueue(_: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct, withDefaultPrice price: NSDecimalNumber) -> Bool {
		x.log(.info).send("should add store payment with default price")
		// log the args
		x.log(.info).send("payment: \(payment)")
		x.log(.info).send("product: \(product)")
		x.log(.info).send("price: \(price)")
		return true
	}

	public func paymentQueue(_: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
		x.log(.info).send("did revoke entitlements for product identifiers: \(productIdentifiers)")
	}

	public func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue) {
		x.log(.info).send("did change storefront: \(queue)")
	}
}
