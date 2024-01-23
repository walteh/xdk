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
		return self.container.viewContext
	}

	public var backgroundContext: NSManagedObjectContext {
		let ctx = self.container.newBackgroundContext()
		ctx.automaticallyMergesChangesFromParent = true
		ctx.mergePolicy = NSMergePolicy.mergeBySkippingZero
		return ctx
	}

	public init(name: String, inMemory: Bool, bundle: Bundle?) {
		if let bundle {
			self.model = .mergedModel(from: [bundle])!
			self.container = .init(name: name, managedObjectModel: self.model)
		} else {
			self.container = .init(name: name)
			self.model = self.container.managedObjectModel
		}

		if inMemory {
			self.container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
		}

		self.container.viewContext.mergePolicy = NSMergePolicy.mergeBySkippingZero
		self.container.viewContext.automaticallyMergesChangesFromParent = true

		self.container.loadPersistentStores { _, error in
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
