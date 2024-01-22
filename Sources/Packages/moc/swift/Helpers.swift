//
//  File.swift
//
//
//  Created by walter on 3/12/23.
//

import Combine
import CoreData
import Foundation

public extension NSManagedObjectContext {
	func publisher<T: NSManagedObject>(for managedObject: T) -> AnyPublisher<T, Never> {
		let notification = NSManagedObjectContext.didMergeChangesObjectIDsNotification
		return NotificationCenter.default.publisher(for: notification, object: self)
			.compactMap { notification in
				if let updated = notification.userInfo?[NSUpdatedObjectIDsKey] as? Set<NSManagedObjectID>,
				   updated.contains(managedObject.objectID),
				   let updatedObject = self.object(with: managedObject.objectID) as? T
				{
					return updatedObject
				} else {
					return nil
				}
			}
			.eraseToAnyPublisher()
	}
}

// public class NSMergeByKeepingPropertiesPolicy: NSMergePolicy {
//	var keypaths: [String]
//
//	public init(keypaths: [String]) {
////		super.init()
//		self.keypaths = keypaths
//		super.init(merge: .mergeByPropertyObjectTrumpMergePolicyType)
//	}
//
//	@objc override public func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
//		guard list.allSatisfy({ $0.databaseObject != nil }) else {
//			print("NSMergeByKeepingPropertiesPolicy is only intended to work with database-level conflicts.")
//			return try super.resolve(constraintConflicts: list)
//		}
//
//		for conflict in list {
//			for conflictingObject in conflict.conflictingObjects {
//				for key in conflictingObject.entity.attributesByName.keys {
//					let databaseValue = conflict.databaseObject?.value(forKey: key)
//					let newvalue = conflictingObject.value(forKey: key)
////					#keyPath()
//					for k in self.keypaths {
//						if key == k { continue }
//					}
//
//					conflictingObject.setValue(databaseValue, forKey: key)
//				}
//			}
//		}
//
//		try super.resolve(constraintConflicts: list)
//	}
// }

public class NSMergeBySkippingZeroPolicy: NSMergePolicy {
	public init() {
		super.init(merge: .mergeByPropertyObjectTrumpMergePolicyType)
	}

	@objc override public func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
		guard list.allSatisfy({ $0.databaseObject != nil }) else {
			print("NSMergeBySkippingZeroPolicy is only intended to work with database-level conflicts.")
			return try super.resolve(constraintConflicts: list)
		}

		for conflict in list {
			for conflictingObject in conflict.conflictingObjects {
				for key in conflictingObject.entity.attributesByName.keys {
					let databaseValue = conflict.databaseObject?.value(forKey: key)
					if let newvalue = conflictingObject.value(forKey: key) {
						if let newvalue = newvalue as? Double {
							if newvalue == 0.0 {
								conflictingObject.setValue(databaseValue, forKey: key)
							}
						} else if let newvalue = newvalue as? String {
							if newvalue == "" {
								conflictingObject.setValue(databaseValue, forKey: key)
							}
						}
					} else {
						conflictingObject.setValue(databaseValue, forKey: key)
					}
				}
			}
		}

		try super.resolve(constraintConflicts: list)
	}
}

public extension NSMergePolicy {
	static let mergeBySkippingZero = NSMergeBySkippingZeroPolicy()
}
