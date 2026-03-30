import Foundation

// MARK: - LiveActivityError

/// Errors that can occur during Live Activity operations.
public enum LiveActivityError: Error, LocalizedError {
    /// Live Activities are not enabled on this device.
    case activitiesNotEnabled
    /// The activity with the given ID was not found.
    case activityNotFound(String)
    /// A simulated failure for testing.
    case simulatedFailure(String)

    public var errorDescription: String? {
        switch self {
        case .activitiesNotEnabled:
            return "Live Activities are not enabled"
        case .activityNotFound(let id):
            return "Activity not found: \(id)"
        case .simulatedFailure(let message):
            return "Simulated failure: \(message)"
        }
    }
}

// MARK: - MockLiveActivityService

/// Mock implementation of `LiveActivityServiceProtocol` for testing.
/// Tracks activity lifecycle (start, update, end) and records all method calls.
public final class MockLiveActivityService: LiveActivityServiceProtocol, @unchecked Sendable {

    // MARK: - Activity Record

    /// Represents the state of a tracked Live Activity.
    public struct ActivityRecord: Equatable {
        public let id: String
        public let attributes: BreakActivityAttributes
        public var currentState: BreakActivityState
        public var isActive: Bool
        public var dismissalPolicy: DismissalPolicy?

        public init(
            id: String,
            attributes: BreakActivityAttributes,
            currentState: BreakActivityState,
            isActive: Bool = true,
            dismissalPolicy: DismissalPolicy? = nil
        ) {
            self.id = id
            self.attributes = attributes
            self.currentState = currentState
            self.isActive = isActive
            self.dismissalPolicy = dismissalPolicy
        }
    }

    // MARK: - State

    /// All tracked activities keyed by their ID.
    public private(set) var activities: [String: ActivityRecord] = [:]

    /// Counter used to generate unique activity IDs.
    private var nextActivityIndex: Int = 0

    // MARK: - Configuration

    /// Whether Live Activities are enabled.
    public var areActivitiesEnabled: Bool = true

    /// Whether `startBreakActivity` should throw.
    public var shouldThrowOnStart: Bool = false

    /// Custom error to throw when configured to fail.
    public var errorToThrow: Error?

    // MARK: - Call Recording

    /// Records of `startBreakActivity` calls.
    public struct StartCall: Equatable {
        public let attributes: BreakActivityAttributes
        public let state: BreakActivityState
    }

    /// Records of `updateBreakActivity` calls.
    public struct UpdateCall: Equatable {
        public let id: String
        public let state: BreakActivityState
    }

    /// Records of `endBreakActivity` calls.
    public struct EndCall: Equatable {
        public let id: String
        public let dismissalPolicy: DismissalPolicy
    }

    /// All recorded `startBreakActivity` calls.
    public private(set) var startCalls: [StartCall] = []

    /// All recorded `updateBreakActivity` calls.
    public private(set) var updateCalls: [UpdateCall] = []

    /// All recorded `endBreakActivity` calls.
    public private(set) var endCalls: [EndCall] = []

    /// Number of times `cleanupOrphanedActivities` has been called.
    public private(set) var cleanupCallCount: Int = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Protocol Implementation

    public func startBreakActivity(
        attributes: BreakActivityAttributes,
        state: BreakActivityState
    ) throws -> String {
        startCalls.append(StartCall(attributes: attributes, state: state))

        if !areActivitiesEnabled {
            throw LiveActivityError.activitiesNotEnabled
        }

        if shouldThrowOnStart {
            throw errorToThrow ?? LiveActivityError.simulatedFailure("Mock configured to fail")
        }

        let id = "mock-activity-\(nextActivityIndex)"
        nextActivityIndex += 1

        activities[id] = ActivityRecord(
            id: id,
            attributes: attributes,
            currentState: state,
            isActive: true
        )

        return id
    }

    public func updateBreakActivity(id: String, state: BreakActivityState) {
        updateCalls.append(UpdateCall(id: id, state: state))

        if var record = activities[id] {
            record.currentState = state
            activities[id] = record
        }
    }

    public func endBreakActivity(id: String, dismissalPolicy: DismissalPolicy) {
        endCalls.append(EndCall(id: id, dismissalPolicy: dismissalPolicy))

        if var record = activities[id] {
            record.isActive = false
            record.dismissalPolicy = dismissalPolicy
            activities[id] = record
        }
    }

    public func cleanupOrphanedActivities() {
        cleanupCallCount += 1

        // Remove all inactive activities (simulating cleanup)
        activities = activities.filter { $0.value.isActive }
    }

    // MARK: - Test Helpers

    /// Reset all call records and state.
    public func reset() {
        activities.removeAll()
        nextActivityIndex = 0
        startCalls.removeAll()
        updateCalls.removeAll()
        endCalls.removeAll()
        cleanupCallCount = 0
        areActivitiesEnabled = true
        shouldThrowOnStart = false
        errorToThrow = nil
    }

    /// Get all currently active activities.
    public var activeActivities: [ActivityRecord] {
        activities.values.filter(\.isActive)
    }

    /// Get all ended activities.
    public var endedActivities: [ActivityRecord] {
        activities.values.filter { !$0.isActive }
    }
}
