import Foundation

// MARK: - ScheduleConfig

/// Configuration for a device activity monitoring schedule.
/// Abstracts `DeviceActivitySchedule` for testability.
public struct ScheduleConfig: Equatable, Sendable {
    /// Hour component of the interval start time (0–23).
    public let startHour: Int
    /// Minute component of the interval start time (0–59).
    public let startMinute: Int
    /// Hour component of the interval end time (0–23).
    public let endHour: Int
    /// Minute component of the interval end time (0–59).
    public let endMinute: Int
    /// Whether the schedule repeats.
    public let repeats: Bool
    /// Optional warning time in minutes before the interval starts/ends.
    public let warningTimeMinutes: Int?

    public init(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        repeats: Bool = true,
        warningTimeMinutes: Int? = nil
    ) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.repeats = repeats
        self.warningTimeMinutes = warningTimeMinutes
    }
}

// MARK: - MonitoringServiceProtocol

/// Protocol abstracting DeviceActivityCenter monitoring operations.
/// Real implementation wraps `DeviceActivityCenter`;
/// mock implementation tracks schedules for testing.
public protocol MonitoringServiceProtocol: AnyObject, Sendable {
    /// Start monitoring a device activity schedule.
    ///
    /// - Parameters:
    ///   - activityName: A unique name for this monitoring activity.
    ///   - schedule: The schedule configuration to monitor.
    /// - Throws: If monitoring cannot be started (e.g., schedule limit reached).
    func startMonitoring(activityName: String, schedule: ScheduleConfig) throws

    /// Stop monitoring one or more named activities.
    ///
    /// - Parameter activityNames: The names of the activities to stop monitoring.
    func stopMonitoring(activityNames: [String])

    /// The names of all currently active monitors.
    var activeMonitors: [String] { get }
}
