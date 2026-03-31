import Foundation

// MARK: - FocusNotification

/// Represents an in-app notification for focus mode lifecycle events.
public struct FocusNotification: Identifiable, Equatable, Sendable {
    /// Unique identifier for this notification.
    public let id: UUID
    /// The message to display (e.g., "Work Focus activated").
    public let message: String
    /// Whether this is a start (activated) or end (ended) notification.
    public let isActivation: Bool
    /// The profile name associated with this notification.
    public let profileName: String
    /// When this notification was created.
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        message: String,
        isActivation: Bool,
        profileName: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.isActivation = isActivation
        self.profileName = profileName
        self.timestamp = timestamp
    }
}

// MARK: - FocusNotificationService

/// Service for managing in-app notifications for focus mode lifecycle events.
/// When a scheduled focus mode starts or ends while the app is in the foreground,
/// this service emits a notification that the UI displays as a banner overlay.
@MainActor
@Observable
public final class FocusNotificationService {

    // MARK: - State

    /// The currently visible notification, if any.
    public private(set) var currentNotification: FocusNotification?

    /// Auto-dismiss duration in seconds.
    public let autoDismissDuration: TimeInterval

    /// Tracks the dismiss work item so it can be cancelled.
    private var dismissWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    /// Creates a notification service with the given auto-dismiss duration.
    ///
    /// - Parameter autoDismissDuration: How long to show notifications before auto-dismissing. Defaults to 3 seconds.
    public init(autoDismissDuration: TimeInterval = 3.0) {
        self.autoDismissDuration = autoDismissDuration
    }

    // MARK: - Show Notifications

    /// Shows a focus mode activation notification.
    ///
    /// - Parameter profileName: The name of the profile that was activated.
    public func showActivation(profileName: String) {
        let notification = FocusNotification(
            message: "\(profileName) Focus activated",
            isActivation: true,
            profileName: profileName
        )
        show(notification)
    }

    /// Shows a focus mode deactivation notification.
    ///
    /// - Parameter profileName: The name of the profile that was deactivated.
    public func showDeactivation(profileName: String) {
        let notification = FocusNotification(
            message: "\(profileName) Focus ended",
            isActivation: false,
            profileName: profileName
        )
        show(notification)
    }

    /// Shows a notification with auto-dismiss.
    ///
    /// - Parameter notification: The notification to display.
    public func show(_ notification: FocusNotification) {
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()

        currentNotification = notification

        // Use a longer auto-dismiss for test accessibility
        let dismissDuration = autoDismissDuration
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration, execute: workItem)
    }

    /// Dismisses the current notification immediately.
    public func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        currentNotification = nil
    }

    /// Whether a notification is currently visible.
    public var isShowingNotification: Bool {
        currentNotification != nil
    }
}
