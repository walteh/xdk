//
//  NSManagedObjectContext.swift
//  app
//
//  Created by walter on 10/18/22.
//

import CoreData
import Foundation
import Err


extension NSManagedObjectContext {
	func saveRecordingError() -> Result<Void, Error> {

		do {
			x.log(.info).send("Need to update \(self.updatedObjects.count) Objects in CoreData")
			try self.save()
		} catch {
			return .failure(x.error("Failed to obtain permanent IDs", root: error))
		}

		return .success(())
	}
}
