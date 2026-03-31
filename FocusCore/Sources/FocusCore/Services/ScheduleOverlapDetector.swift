import Foundation

// MARK: - ScheduleConflict

/// Represents a scheduling conflict between two focus mode profiles.
public struct ScheduleConflict: Equatable, Sendable {
    /// Name of the first conflicting profile.
    public let profileName1: String
    /// Name of the second conflicting profile.
    public let profileName2: String
    /// Days on which the conflict occurs.
    public let overlappingDays: [Weekday]
    /// Description of the overlapping time range.
    public let timeDescription: String

    public init(
        profileName1: String,
        profileName2: String,
        overlappingDays: [Weekday],
        timeDescription: String
    ) {
        self.profileName1 = profileName1
        self.profileName2 = profileName2
        self.overlappingDays = overlappingDays
        self.timeDescription = timeDescription
    }
}

// MARK: - ScheduleOverlapDetector

/// Detects scheduling conflicts between focus mode profiles.
/// Checks for time and day overlaps between schedules.
public struct ScheduleOverlapDetector: Sendable {

    public init() {}

    /// Checks whether two schedules overlap on any day/time combination.
    ///
    /// - Parameters:
    ///   - schedule1: The first schedule to check.
    ///   - schedule2: The second schedule to check.
    /// - Returns: The overlapping days, or an empty array if no overlap.
    public func findOverlappingDays(
        _ schedule1: ScheduleConfig,
        _ schedule2: ScheduleConfig
    ) -> [Weekday] {
        // Find days that both schedules could potentially be active on
        var overlappingDays: [Weekday] = []

        // For each day in the week, check if both schedules are active and times overlap
        for day in Weekday.allCases {
            if schedulesOverlapOnDay(schedule1, schedule2, day: day) {
                overlappingDays.append(day)
            }
        }

        return overlappingDays.sorted()
    }

    /// Checks if two schedules overlap on a specific day.
    private func schedulesOverlapOnDay(
        _ s1: ScheduleConfig,
        _ s2: ScheduleConfig,
        day: Weekday
    ) -> Bool {
        let ranges1 = activeTimeRangesOnDay(s1, day: day)
        let ranges2 = activeTimeRangesOnDay(s2, day: day)

        for r1 in ranges1 {
            for r2 in ranges2 {
                if timeRangesOverlap(r1, r2) {
                    return true
                }
            }
        }
        return false
    }

    /// Returns the active time ranges (in minutes from midnight) for a schedule on a given day.
    /// An overnight schedule may produce a range on the start day and a separate range on the next day.
    private func activeTimeRangesOnDay(
        _ schedule: ScheduleConfig,
        day: Weekday
    ) -> [(start: Int, end: Int)] {
        var ranges: [(start: Int, end: Int)] = []

        if schedule.isOvernight {
            // Overnight: e.g., 22:00 - 07:00
            // On the start day: active from startTime to midnight (1440)
            if schedule.days.contains(day) {
                ranges.append((start: schedule.startTotalMinutes, end: 1440))
            }
            // On the next day: active from midnight (0) to endTime
            let previousDay = day.previousDay
            if schedule.days.contains(previousDay) {
                ranges.append((start: 0, end: schedule.endTotalMinutes))
            }
        } else {
            // Same-day: e.g., 09:00 - 17:00
            if schedule.days.contains(day) {
                ranges.append((start: schedule.startTotalMinutes, end: schedule.endTotalMinutes))
            }
        }

        return ranges
    }

    /// Checks if two time ranges (in minutes) overlap.
    /// Ranges are [start, end) — start is inclusive, end is exclusive.
    private func timeRangesOverlap(
        _ r1: (start: Int, end: Int),
        _ r2: (start: Int, end: Int)
    ) -> Bool {
        return r1.start < r2.end && r2.start < r1.end
    }

    /// Detects all conflicts between a target schedule and a list of existing profiles.
    ///
    /// - Parameters:
    ///   - targetSchedule: The schedule being checked.
    ///   - targetProfileName: The name of the profile being checked.
    ///   - existingProfiles: List of tuples (profileName, schedule) for existing profiles.
    ///   - excludeProfileId: Optional profile ID to exclude (for edit mode — exclude self).
    /// - Returns: A list of conflicts found.
    public func detectConflicts(
        targetSchedule: ScheduleConfig,
        targetProfileName: String,
        existingProfiles: [(name: String, id: UUID, schedule: ScheduleConfig)],
        excludeProfileId: UUID? = nil
    ) -> [ScheduleConflict] {
        var conflicts: [ScheduleConflict] = []

        for existing in existingProfiles {
            // Skip the profile being edited
            if let excludeId = excludeProfileId, existing.id == excludeId {
                continue
            }

            let overlappingDays = findOverlappingDays(targetSchedule, existing.schedule)
            if !overlappingDays.isEmpty {
                let timeDesc = formatTimeOverlap(targetSchedule, existing.schedule)
                let conflict = ScheduleConflict(
                    profileName1: targetProfileName,
                    profileName2: existing.name,
                    overlappingDays: overlappingDays,
                    timeDescription: timeDesc
                )
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    /// Formats a human-readable description of the overlapping time range.
    private func formatTimeOverlap(
        _ s1: ScheduleConfig,
        _ s2: ScheduleConfig
    ) -> String {
        let time1 = formatTimeRange(s1)
        let time2 = formatTimeRange(s2)
        return "\(time1) overlaps with \(time2)"
    }

    /// Formats a schedule's time range as a string.
    private func formatTimeRange(_ schedule: ScheduleConfig) -> String {
        let startStr = String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)
        let endStr = String(format: "%02d:%02d", schedule.endHour, schedule.endMinute)
        return "\(startStr)-\(endStr)"
    }
}
