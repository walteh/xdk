
import Foundation

import XDKKeychain
import XDKX

public enum moc {
	public typealias API = MOCAPI
	public enum client {
		public typealias Memory = MOCMemoryClient
		public typealias Storage = MOCStorageClient
	}
}
