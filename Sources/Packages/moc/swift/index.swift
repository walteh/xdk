
import Foundation

import keychain_swift
import x_swift

public enum moc {
	public typealias API = MOCAPI
	public enum client {
		public typealias Memory = MOCMemoryClient
		public typealias Storage = MOCStorageClient
	}
}
