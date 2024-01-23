//
//  NSManagedObjectContext.swift
//  app
//
//  Created by walter on 10/18/22.
//

import CoreData
import Foundation

extension NSManagedObjectContext {
	func saveRecordingError() -> Result<Void, Error> {
		x.log(.info).send("Need to update \(self.updatedObjects.count) Objects in CoreData")
		return Result.X { try self.save() }
	}
}
