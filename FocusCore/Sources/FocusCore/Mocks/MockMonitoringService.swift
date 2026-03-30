import Foundation

// MARK: - MonitoringError

/// Errors that can occur during monitoring operations.
public enum MonitoringError: Error, LocalizedError {
    /// The maximum number of active schedules (20) has been reached.
    case scheduleLimitReached
    /// A simulated failure for testing.
    case simulatedFailure(String)

    public var errorDescription: String? {
        switch self {
        case .scheduleLimitReached:
            return "Maximum number of active schedules (20) reached"
        case .simulatedFailure(let message):
            return "Simulated failure: \(message)"
        }
    }
}

// MARK: - MockMonitoringService

/// Mock implementation of `MonitoringServiceProtocol` for testing.
/// Tracks active monitors and their schedules, and records all method calls.
public final class MockMonitoringService: MonitoringServiceProtocol, @unchecked Sendable {

    // MARK: - Constants

    /// Maximum number of allowed active schedules, matching DeviceActivityCenter's limit.
    public static let maxSchedules = 20

    // MARK: - State

    /// Active monitors mapped by activity name to schedule configuration.
    public private(set) var monitorSchedules: [String: ScheduleConfig] = [:]

    /// The names of all currently active monitors.
    public var activeMonitors: [String] {
        Array(monitorSchedules.keys).sorted()
    }

    // MARK: - Call Recording

    /// Records of `startMonitoring` calls.
    public struct StartMonitoringCall: Equatable {
        public let activityName: String
        public let schedule: ScheduleConfig
    }

    /// All recorded `startMonitoring` calls.
    public private(set) var startMonitoringCalls: [StartMonitoringCall] = []

    /// All recorded `stopMonitoring` calls (arrays of activity names).
    public private(set) var stopMonitoringCalls: [[String]] = []

    // MARK: - Configuration

    /// Whether `startMonitoring` should enforce the 20-schedule limit.
    public var enforceScheduleLimit: Bool = true

    /// Whether `startMonitoring` should throw a custom error.
    public var shouldThrowOnStart: Bool = false

    /// Custom error to throw when `shouldThrowOnStart` is `true`.
    public var errorToThrow: Error?

    // MARK: - Initialization

    public init() {}

    // MARK: - Protocol Implementation

    public func startMonitoring(activityName: String, schedule: ScheduleConfig) throws {
        let call = StartMonitoringCall(activityName: activityName, schedule: schedule)
        startMonitoringCalls.append(call)

        if shouldThrowOnStart {
            throw errorToThrow ?? MonitoringError.simulatedFailure("Mock configured to fail")
        }

        if enforceScheduleLimit && monitorSchedules.count >= Self.maxSchedules
            && monitorSchedules[activityName] == nil {
            throw MonitoringError.scheduleLimitReached
        }

        monitorSchedules[activityName] = schedule
    }

    public func stopMonitoring(activityNames: [String]) {
        stopMonitoringCalls.append(activityNames)

        for name in activityNames {
            monitorSchedules.removeValue(forKey: name)
        }
    }

    // MARK: - Test Helpers

    /// Reset all call records and state.
    public func reset() {
        monitorSchedules.removeAll()
        startMonitoringCalls.removeAll()
        stopMonitoringCalls.removeAll()
        shouldThrowOnStart = false
        errorToThrow = nil
    }
}
