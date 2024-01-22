//
//  NSManagedObjectContext.swift
//  app
//
//  Created by walter on 10/18/22.
//

import CoreData
import Foundation

extension NSManagedObjectContext {
	func saveRecordingError() throws {
		do {
			print("Need to update \(self.updatedObjects.count) Objects in CoreData")
			try self.save()
		} catch let error as NSError {
			x.error(error)
			throw error
		}
	}
}
