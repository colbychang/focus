import Foundation

// MARK: - WeeklyAverageCalculator

/// Calculates the mean of daily focus times over a 7-day week.
///
/// Rules:
/// - Full week: sum of daily focus times divided by 7.
/// - Partial week: average over actual days with data (not 7).
/// - Zero-session days within the user's active period count as 0.
///   "Active period" = from the first session date to the current date.
/// - Week boundaries follow the locale's `calendar.firstWeekday`.
/// - Sessions are attributed to the day of their `startTime` (device local time).
/// - Only `.completed` sessions count toward focus time.
public struct WeeklyAverageCalculator: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Calculate Weekly Average

    /// Computes the average daily focus time for a given week.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - weekContaining: A date within the target week.
    ///   - calendar: Calendar for week boundary and day calculations.
    /// - Returns: Average daily focus time in seconds for the specified week.
    public func weeklyAverage(
        sessions: [DeepFocusSession],
        weekContaining date: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let completedSessions = sessions.filter { $0.status == .completed }

        // Find week start and end
        let weekRange = weekDateRange(for: date, calendar: calendar)
        let weekStart = weekRange.start
        let weekEnd = weekRange.end

        // Filter sessions to this week (attributed by start date)
        let weekSessions = completedSessions.filter { session in
            let sessionDay = calendar.startOfDay(for: session.startTime)
            return sessionDay >= weekStart && sessionDay < weekEnd
        }

        guard !weekSessions.isEmpty else { return 0 }

        // Determine how many days to divide by:
        // If we have data for the full week, divide by 7.
        // For partial weeks, divide by actual days with data.
        let daysWithData = uniqueDays(for: weekSessions, calendar: calendar)

        // Calculate the total focus time for the week
        let totalFocusTime = weekSessions.reduce(0.0) { $0 + $1.configuredDuration }

        return totalFocusTime / Double(daysWithData.count)
    }

    /// Computes the average daily focus time for the current week.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - now: The current date (injectable for testing).
    ///   - calendar: Calendar for week boundary and day calculations.
    /// - Returns: Average daily focus time in seconds for the current week.
    public func currentWeekAverage(
        sessions: [DeepFocusSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeInterval {
        return weeklyAverage(sessions: sessions, weekContaining: now, calendar: calendar)
    }

    // MARK: - Week Date Range

    /// Returns the start (inclusive) and end (exclusive) dates of the week containing the given date.
    ///
    /// - Parameters:
    ///   - date: A date within the target week.
    ///   - calendar: Calendar determining week boundaries (respects `firstWeekday`).
    /// - Returns: Tuple of (start of week, start of next week).
    public func weekDateRange(
        for date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        // Find the start of the week per the calendar's locale settings
        var weekStart = date
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &weekStart, interval: &interval, for: date)
        let weekEnd = weekStart.addingTimeInterval(interval)
        return (calendar.startOfDay(for: weekStart), calendar.startOfDay(for: weekEnd))
    }

    // MARK: - Helpers

    /// Returns the unique set of days with data.
    private func uniqueDays(
        for sessions: [DeepFocusSession],
        calendar: Calendar
    ) -> Set<DateComponents> {
        var days = Set<DateComponents>()
        for session in sessions {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: session.startTime)
            days.insert(dayComponents)
        }
        return days
    }
}
