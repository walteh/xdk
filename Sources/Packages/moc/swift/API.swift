//
//  File.swift
//
//
//  Created by walter on 3/11/23.
//

import Combine
import CoreData
import Foundation

public protocol MOCAPI {
//	var container: NSPersistentContainer { get }
	var viewContext: NSManagedObjectContext { get }
	var backgroundContext: NSManagedObjectContext { get }
}
