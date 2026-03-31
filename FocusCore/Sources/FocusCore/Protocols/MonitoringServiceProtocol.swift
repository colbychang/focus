import Foundation

// MARK: - ScheduleConfig

/// Configuration for a device activity monitoring schedule.
/// Abstracts `DeviceActivitySchedule` for testability.
/// Supports same-day and overnight (cross-midnight) schedules.
public struct ScheduleConfig: Equatable, Sendable, Codable {
    /// Days of the week when this schedule is active.
    public let days: [Weekday]
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
        days: [Weekday] = [],
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        repeats: Bool = true,
        warningTimeMinutes: Int? = nil
    ) {
        self.days = days
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.repeats = repeats
        self.warningTimeMinutes = warningTimeMinutes
    }

    /// Whether this is an overnight schedule (start time > end time, crossing midnight).
    public var isOvernight: Bool {
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        return startMinutes > endMinutes
    }

    /// Start time as total minutes from midnight.
    public var startTotalMinutes: Int {
        startHour * 60 + startMinute
    }

    /// End time as total minutes from midnight.
    public var endTotalMinutes: Int {
        endHour * 60 + endMinute
    }
}

// MARK: - ScheduleValidationError

/// Errors that can occur during schedule validation.
public enum ScheduleValidationError: Error, LocalizedError, Equatable {
    /// No days were selected for the schedule.
    case noDaysSelected
    /// Start time equals end time (zero-duration schedule).
    case zeroDuration
    /// Hour value is out of valid range (0-23).
    case invalidHour(Int)
    /// Minute value is out of valid range (0-59).
    case invalidMinute(Int)

    public var errorDescription: String? {
        switch self {
        case .noDaysSelected:
            return "At least one day must be selected"
        case .zeroDuration:
            return "Start and end times cannot be the same"
        case .invalidHour(let hour):
            return "Invalid hour: \(hour). Must be 0-23"
        case .invalidMinute(let minute):
            return "Invalid minute: \(minute). Must be 0-59"
        }
    }
}

// MARK: - ScheduleConfig Validation

extension ScheduleConfig {

    /// Validates the schedule configuration.
    /// - Throws: `ScheduleValidationError` if the configuration is invalid.
    public func validate() throws {
        // Validate at least one day selected
        guard !days.isEmpty else {
            throw ScheduleValidationError.noDaysSelected
        }

        // Validate hour ranges
        guard (0...23).contains(startHour) else {
            throw ScheduleValidationError.invalidHour(startHour)
        }
        guard (0...23).contains(endHour) else {
            throw ScheduleValidationError.invalidHour(endHour)
        }

        // Validate minute ranges
        guard (0...59).contains(startMinute) else {
            throw ScheduleValidationError.invalidMinute(startMinute)
        }
        guard (0...59).contains(endMinute) else {
            throw ScheduleValidationError.invalidMinute(endMinute)
        }

        // Validate non-zero duration
        guard startTotalMinutes != endTotalMinutes else {
            throw ScheduleValidationError.zeroDuration
        }
    }

    /// Checks whether a given time (hour, minute) on a given weekday falls within this schedule.
    /// - Parameters:
    ///   - hour: The hour to check (0-23).
    ///   - minute: The minute to check (0-59).
    ///   - weekday: The weekday to check.
    /// - Returns: `true` if the time/day is within the schedule.
    public func containsTime(hour: Int, minute: Int, weekday: Weekday) -> Bool {
        let checkMinutes = hour * 60 + minute

        if isOvernight {
            // Overnight schedule: e.g., 22:00 - 07:00
            // For the start day: time must be >= startTime
            // For the next day: time must be < endTime
            if days.contains(weekday) && checkMinutes >= startTotalMinutes {
                return true
            }
            // Check if this is the "next day" part of an overnight schedule
            let previousDay = weekday.previousDay
            if days.contains(previousDay) && checkMinutes < endTotalMinutes {
                return true
            }
            return false
        } else {
            // Same-day schedule: e.g., 09:00 - 17:00
            guard days.contains(weekday) else { return false }
            return checkMinutes >= startTotalMinutes && checkMinutes < endTotalMinutes
        }
    }
}

// MARK: - Weekday Navigation

extension Weekday {
    /// The previous day of the week (wraps Saturday → Sunday becomes Sunday → Saturday).
    public var previousDay: Weekday {
        switch self {
        case .sunday: return .saturday
        case .monday: return .sunday
        case .tuesday: return .monday
        case .wednesday: return .tuesday
        case .thursday: return .wednesday
        case .friday: return .thursday
        case .saturday: return .friday
        }
    }

    /// The next day of the week (wraps Saturday → Sunday).
    public var nextDay: Weekday {
        switch self {
        case .sunday: return .monday
        case .monday: return .tuesday
        case .tuesday: return .wednesday
        case .wednesday: return .thursday
        case .thursday: return .friday
        case .friday: return .saturday
        case .saturday: return .sunday
        }
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
