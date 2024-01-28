
import Foundation

import XDK
import XDKKeychain

public enum moc {
	public typealias API = MOCAPI
	public enum client {
		public typealias Memory = MOCMemoryClient
		public typealias Storage = MOCStorageClient
	}
}
