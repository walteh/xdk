import Foundation

extension NSNotification.Name {
	static let Err = Notification.Name("XDK.Error")
}

public protocol ErrorHandler {
	init(onError: @Sendable @escaping (any Error) -> Void)
}

public class NotificationCenterErrorHandler: ErrorHandler {
	var oberver: NSObjectProtocol? = nil


	public required init(onError: @escaping @Sendable (any Error) -> Void) {
		self.oberver = NotificationCenter.default.addObserver(forName: .Err, object: nil, queue: nil) { note in
			if let err = note.object as? Error {
				Log(.error).err(err).send("error notify event received")
				onError(err)
			}
		}
	}

	deinit {
		if let o = self.oberver {
			NotificationCenter.default.removeObserver(o)
		}
	}
}

public extension XError {
	func notify() -> Self {
		NotificationCenter.default.post(name: .Err, object: self)
		return self
	}
}
