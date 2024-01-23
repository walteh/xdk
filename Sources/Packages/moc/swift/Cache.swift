//
//  Cache.swift
//  app
//
//  Created by walter on 10/23/22.
//

import CoreData
import Foundation

import XDKX

extension NSManagedObject {
	func specialID(_ id: String) -> String {
		"\(entity.name!)-\(id)"
	}
}

extension NSEntityDescription {
	func specialID(_ id: String) -> String {
		"\(name!)-\(id)"
	}
}

public class CoreDataIDCacher {
	static var lastCache: [String: NSManagedObjectID] = [:]

	var cache: [String: NSManagedObjectID] = [:]

	var context: UnsafeMutablePointer<NSManagedObjectContext>

	init(context: UnsafeMutablePointer<NSManagedObjectContext>) throws {
		self.context = context
	}

	public static func scoopLastCache<T: NSManagedObject>(at: String, context: NSManagedObjectContext) -> T? {
		let id = self.lastCache[T.entity().specialID(at)]
		if id == nil {
			return nil
		}
		return context.object(with: id!) as! T?
	}

	public func scoop<T: NSManagedObject>(at: String) -> T {
		let id = self.cache[T.entity().specialID(at)]
		if id == nil {
			return self.poop(at: at)
		}
		return self.context.pointee.object(with: id!) as! T? ?? self.poop(at: at)
	}

	public func poop<T: NSManagedObject>(at: String) -> T {
		let id = T.entity().specialID(at)

		guard let res = cache[id] else {
			let r = T(context: context.pointee)
			r.setValue(at, forKey: "external_id")
			self.cache[id] = r.objectID
			return r
		}

		return self.context.pointee.object(with: res) as! T
	}

//	func fillCacheJustForBlock() throws {
//		let timer = x.Timer(name: "fillCacheJustForBlock")
//
//		let blocks = try context.pointee.fetch(Block.fetchRequest())
//
//		for task in blocks { self.cache[task.specialId(task.external_id!)] = task.objectID }
//
//		timer.end()
//	}

//	func fillCache() throws {
//		let timer = x.Timer(name: "setCache")
//
//		let blocks = try context.pointee.fetch(Block.fetchRequest())
//
//		let signers = try context.pointee.fetch(Signer.fetchRequest())
//		let nuggs = try context.pointee.fetch(Nugg.fetchRequest())
//		let items = try context.pointee.fetch(Item.fetchRequest())
//		let swaps = try context.pointee.fetch(Swap.fetchRequest())
//		let nuggitems = try context.pointee.fetch(NuggItem.fetchRequest())
//		let offers = try context.pointee.fetch(Offer.fetchRequest())
//		let proofs = try context.pointee.fetch(Proof.fetchRequest())
//		let snapshots = try context.pointee.fetch(Snapshot.fetchRequest())
//
//		for task in blocks { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in signers { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in nuggs { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in items { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in swaps { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in nuggitems { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in offers { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in proofs { self.cache[task.specialId(task.external_id!)] = task.objectID }
//		for task in snapshots { self.cache[task.specialId(task.external_id!)] = task.objectID }
//
//		timer.end()
//
//		CoreDataIDCacher.lastCache = self.cache
//	}
}
