import Foundation

// MARK: - DarwinNotificationName

/// Darwin notification names for cross-process IPC.
/// Used for real-time signaling between DeviceActivityMonitorExtension and the main app.
public enum DarwinNotificationName {
    /// Posted by the extension when a scheduled focus mode starts (intervalDidStart).
    public static let focusModeStarted = "com.colbychang.focus.focusModeStarted"
    /// Posted by the extension when a scheduled focus mode ends (intervalDidEnd).
    public static let focusModeEnded = "com.colbychang.focus.focusModeEnded"
}

// MARK: - DarwinNotificationPoster

/// Posts Darwin notifications for cross-process IPC.
/// Used by extensions to signal the main app about lifecycle events.
/// Darwin notifications carry no payload — the receiver reads data from App Group UserDefaults.
public enum DarwinNotificationPoster {

    /// Posts a Darwin notification with the given name.
    ///
    /// - Parameter name: The notification name string.
    public static func post(name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

// MARK: - DarwinNotificationObserver

/// Observes Darwin notifications for cross-process IPC.
/// Used by the main app to receive real-time signals from extensions.
public final class DarwinNotificationObserver: @unchecked Sendable {

    // MARK: - Properties

    private let name: String
    private var handler: (() -> Void)?
    private var isObserving = false

    // MARK: - Initialization

    /// Creates a Darwin notification observer.
    ///
    /// - Parameters:
    ///   - name: The Darwin notification name to observe.
    ///   - handler: The closure to call when the notification is received.
    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }

    deinit {
        stopObserving()
    }

    // MARK: - Observe

    /// Starts observing the Darwin notification.
    public func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let `self` = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue()
                self.handler?()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Stops observing the Darwin notification.
    public func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(name as CFString), nil)
    }
}
