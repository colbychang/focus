import Foundation
import SwiftData

// MARK: - ScheduleManagerError

/// Errors that can occur during schedule management operations.
public enum ScheduleManagerError: Error, LocalizedError, Equatable {
    /// The maximum number of active schedules (20) has been reached.
    case scheduleLimitReached(currentCount: Int)
    /// Schedule validation failed.
    case validationFailed(String)
    /// The profile was not found.
    case profileNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .scheduleLimitReached(let count):
            return "Cannot add schedule: \(count) of 20 maximum schedules are in use. Remove some schedules first."
        case .validationFailed(let reason):
            return "Schedule validation failed: \(reason)"
        case .profileNotFound(let id):
            return "Profile with ID \(id) not found"
        }
    }
}

// MARK: - ScheduleManager

/// Manages the lifecycle of DeviceActivity monitoring schedules for focus mode profiles.
/// Handles starting, stopping, and re-registering monitoring schedules,
/// with enforcement of the 20-schedule limit.
@MainActor
public final class ScheduleManager {

    // MARK: - Constants

    /// Maximum number of concurrent schedules allowed by DeviceActivityCenter.
    public static let maxScheduleCount = 20

    // MARK: - Dependencies

    private let monitoringService: MonitoringServiceProtocol
    private let shieldService: ShieldServiceProtocol
    private let sharedStateService: SharedStateService

    // MARK: - Initialization

    /// Creates a ScheduleManager with the given dependencies.
    ///
    /// - Parameters:
    ///   - monitoringService: The monitoring service for schedule registration.
    ///   - shieldService: The shield service for checking active shields.
    ///   - sharedStateService: The shared state service for cross-extension state.
    public init(
        monitoringService: MonitoringServiceProtocol,
        shieldService: ShieldServiceProtocol,
        sharedStateService: SharedStateService
    ) {
        self.monitoringService = monitoringService
        self.shieldService = shieldService
        self.sharedStateService = sharedStateService
    }

    // MARK: - Schedule Registration

    /// Registers a monitoring schedule for a focus mode profile.
    /// Stops any existing schedule for the profile first, then starts the new one.
    ///
    /// - Parameters:
    ///   - profile: The focus mode profile to register monitoring for.
    ///   - schedule: The schedule configuration to register.
    /// - Throws: `ScheduleManagerError.scheduleLimitReached` if the limit would be exceeded,
    ///           `ScheduleValidationError` if the schedule is invalid.
    public func registerSchedule(for profile: FocusMode, schedule: ScheduleConfig) throws {
        // Validate the schedule
        try schedule.validate()

        let activityName = activityName(for: profile)

        // Check if this profile already has a schedule registered
        let currentMonitors = monitoringService.activeMonitors
        let isReplacing = currentMonitors.contains(activityName)

        // If not replacing, check the schedule limit
        if !isReplacing {
            let currentCount = currentMonitors.count
            guard currentCount < Self.maxScheduleCount else {
                throw ScheduleManagerError.scheduleLimitReached(currentCount: currentCount)
            }
        }

        // Stop existing schedule first (prevents startMonitoring side-effect of triggering intervalDidEnd)
        if isReplacing {
            monitoringService.stopMonitoring(activityNames: [activityName])
        }

        // Start new monitoring
        try monitoringService.startMonitoring(activityName: activityName, schedule: schedule)
    }

    /// Unregisters the monitoring schedule for a focus mode profile.
    ///
    /// - Parameter profile: The focus mode profile to stop monitoring for.
    public func unregisterSchedule(for profile: FocusMode) {
        let activityName = activityName(for: profile)
        monitoringService.stopMonitoring(activityNames: [activityName])
    }

    /// Re-registers schedules for all active profiles with schedules.
    /// Called on app launch to restore monitoring after restart.
    ///
    /// - Parameter profiles: The profiles to re-register. Only profiles with
    ///   non-empty scheduleDays will be registered.
    /// - Returns: List of profiles that failed to re-register (e.g., due to limit).
    @discardableResult
    public func reregisterActiveSchedules(profiles: [FocusMode]) -> [(FocusMode, Error)] {
        var failures: [(FocusMode, Error)] = []

        for profile in profiles {
            guard !profile.scheduleDays.isEmpty else { continue }

            let schedule = scheduleConfig(from: profile)
            do {
                try registerSchedule(for: profile, schedule: schedule)
            } catch {
                failures.append((profile, error))
            }
        }

        return failures
    }

    // MARK: - intervalDidEnd Guard

    /// Guards against spurious `intervalDidEnd` calls.
    /// Checks whether we are still within the scheduled interval before allowing shield removal.
    ///
    /// The `startMonitoring` call has a known side effect of triggering `intervalDidEnd`
    /// when replacing an existing schedule. This guard prevents removing shields mid-interval.
    ///
    /// - Parameters:
    ///   - activityName: The activity name that ended.
    ///   - profile: The associated focus mode profile.
    ///   - currentDate: The current date/time (injectable for testing).
    /// - Returns: `true` if shields should be removed (genuine end), `false` if spurious.
    public func shouldRemoveShieldsOnIntervalEnd(
        activityName: String,
        profile: FocusMode,
        currentDate: Date = Date()
    ) -> Bool {
        // If the profile was manually activated, don't remove shields on intervalDidEnd
        // (manual activation takes precedence over scheduled activation)
        if profile.isActive && profile.isManuallyActivated {
            return false
        }

        if profile.isActive && !profile.scheduleDays.isEmpty {
            // Check if we're still within the scheduled time window
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: currentDate)
            let minute = calendar.component(.minute, from: currentDate)
            let weekdayComponent = calendar.component(.weekday, from: currentDate)

            guard let weekday = Weekday(dayNumber: weekdayComponent) else {
                return true // Can't determine weekday, allow removal
            }

            let schedule = scheduleConfig(from: profile)
            if schedule.containsTime(hour: hour, minute: minute, weekday: weekday) {
                // We're still within the scheduled interval — this is a spurious call
                return false
            }
        }

        return true
    }

    // MARK: - Helpers

    /// Generates the activity name for a focus mode profile.
    /// Uses the profile's UUID for deterministic naming across launches.
    public func activityName(for profile: FocusMode) -> String {
        "focus_\(profile.id.uuidString)"
    }

    /// Creates a ScheduleConfig from a FocusMode's stored schedule data.
    public func scheduleConfig(from profile: FocusMode) -> ScheduleConfig {
        let days = profile.scheduleDays.compactMap { Weekday(dayNumber: $0) }
        return ScheduleConfig(
            days: days,
            startHour: profile.scheduleStartHour,
            startMinute: profile.scheduleStartMinute,
            endHour: profile.scheduleEndHour,
            endMinute: profile.scheduleEndMinute,
            repeats: true
        )
    }

    /// Returns the current count of active monitors.
    public var activeScheduleCount: Int {
        monitoringService.activeMonitors.count
    }

    /// Returns the remaining number of schedules that can be added.
    public var remainingScheduleSlots: Int {
        max(0, Self.maxScheduleCount - activeScheduleCount)
    }
}
