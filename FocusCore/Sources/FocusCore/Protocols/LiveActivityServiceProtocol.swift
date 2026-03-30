import Foundation

// MARK: - BreakActivityAttributes

/// Static attributes for a break timer Live Activity.
/// Conforms to `Codable` and `Hashable` as required by ActivityKit.
public struct BreakActivityAttributes: Codable, Hashable, Sendable {
    /// The total break duration in seconds.
    public let breakDuration: TimeInterval
    /// The name of the associated focus session, if any.
    public let sessionName: String?

    public init(breakDuration: TimeInterval, sessionName: String? = nil) {
        self.breakDuration = breakDuration
        self.sessionName = sessionName
    }
}

// MARK: - BreakActivityState

/// Dynamic content state for a break timer Live Activity.
/// Conforms to `Codable` and `Hashable` as required by ActivityKit.
public struct BreakActivityState: Codable, Hashable, Sendable {
    /// The date when the break ends.
    public let endDate: Date
    /// Remaining seconds in the break.
    public let remainingSeconds: TimeInterval
    /// Whether the break is currently active.
    public let isActive: Bool

    public init(endDate: Date, remainingSeconds: TimeInterval, isActive: Bool = true) {
        self.endDate = endDate
        self.remainingSeconds = remainingSeconds
        self.isActive = isActive
    }
}

// MARK: - DismissalPolicy

/// Policy for dismissing a Live Activity when it ends.
/// Mirrors ActivityKit's `ActivityUIDismissalPolicy`.
public enum DismissalPolicy: Equatable, Sendable {
    /// System removes after default period (~4 hours) or user dismisses.
    case `default`
    /// Removed instantly.
    case immediate
    /// Removed after a specific date.
    case after(Date)
}

// MARK: - LiveActivityServiceProtocol

/// Protocol abstracting ActivityKit Live Activity operations for break timers.
/// Real implementation wraps `Activity<BreakActivityAttributes>`;
/// mock implementation tracks activity lifecycle for testing.
public protocol LiveActivityServiceProtocol: AnyObject, Sendable {
    /// Start a break timer Live Activity.
    ///
    /// - Parameters:
    ///   - attributes: The static attributes for the activity.
    ///   - state: The initial dynamic content state.
    /// - Returns: A unique identifier for the started activity.
    /// - Throws: If the activity cannot be started.
    func startBreakActivity(
        attributes: BreakActivityAttributes,
        state: BreakActivityState
    ) throws -> String

    /// Update a break timer Live Activity's dynamic state.
    ///
    /// - Parameters:
    ///   - id: The identifier of the activity to update.
    ///   - state: The new dynamic content state.
    func updateBreakActivity(id: String, state: BreakActivityState)

    /// End a break timer Live Activity.
    ///
    /// - Parameters:
    ///   - id: The identifier of the activity to end.
    ///   - dismissalPolicy: How the activity should be dismissed from the UI.
    func endBreakActivity(id: String, dismissalPolicy: DismissalPolicy)

    /// Clean up any orphaned Live Activities from previous sessions.
    func cleanupOrphanedActivities()

    /// Whether Live Activities are enabled on this device.
    var areActivitiesEnabled: Bool { get }
}
