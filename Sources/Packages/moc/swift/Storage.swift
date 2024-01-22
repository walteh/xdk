//
//  Storage.swift
//  app
//
//  Created by walter on 10/23/22.
//

import Combine
import CoreData
import Foundation
import SwiftUI

import XDKX

open class MOCClient: NSObject, MOCAPI {
	let container: NSPersistentContainer

	let model: NSManagedObjectModel

//	let context: NSManagedObjectContext

	public var viewContext: NSManagedObjectContext {
		return container.viewContext
	}

	public var backgroundContext: NSManagedObjectContext {
		let ctx = container.newBackgroundContext()
		ctx.automaticallyMergesChangesFromParent = true
		ctx.mergePolicy = NSMergePolicy.mergeBySkippingZero
		return ctx
	}

	public init(name: String, inMemory: Bool, bundle: Bundle?) {
		if let bundle {
			model = .mergedModel(from: [bundle])!
			container = .init(name: name, managedObjectModel: model)
		} else {
			container = .init(name: name)
			model = container.managedObjectModel
		}

		if inMemory {
			container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
		}

		container.viewContext.mergePolicy = NSMergePolicy.mergeBySkippingZero
		container.viewContext.automaticallyMergesChangesFromParent = true

		container.loadPersistentStores { _, error in
			if let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}
	}
}

public class MOCStorageClient: MOCClient {
	public init(name: String, bundle: Bundle? = nil) {
		super.init(name: name, inMemory: false, bundle: bundle)
	}
}

public class MOCMemoryClient: MOCClient {
	public init(name: String, bundle: Bundle? = nil) {
		super.init(name: name, inMemory: true, bundle: bundle)
	}
}
