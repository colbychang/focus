import Foundation

// MARK: - MonthlyAverageCalculator

/// Calculates the mean of daily focus times over a calendar month.
///
/// Rules:
/// - Full month: sum of daily focus times divided by the number of days in the month (28/29/30/31).
/// - Empty month (no sessions): returns 0.
/// - Partial month: average over actual days with data (not total month days).
/// - Leap year February: uses 29 days when applicable.
/// - Only `.completed` sessions count toward focus time.
/// - Sessions are attributed to the day of their `startTime` (device local time).
public struct MonthlyAverageCalculator: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Calculate Monthly Average

    /// Computes the average daily focus time for a given month.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - year: The year of the target month.
    ///   - month: The month (1–12) of the target month.
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Average daily focus time in seconds for the specified month.
    public func monthlyAverage(
        sessions: [DeepFocusSession],
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let completedSessions = sessions.filter { $0.status == .completed }

        // Find month start and end
        let monthRange = monthDateRange(year: year, month: month, calendar: calendar)
        guard let monthStart = monthRange.start, let monthEnd = monthRange.end else {
            return 0
        }

        // Filter sessions to this month (attributed by start date)
        let monthSessions = completedSessions.filter { session in
            let sessionDay = calendar.startOfDay(for: session.startTime)
            return sessionDay >= monthStart && sessionDay < monthEnd
        }

        guard !monthSessions.isEmpty else { return 0 }

        // Calculate total focus time
        let totalFocusTime = monthSessions.reduce(0.0) { $0 + $1.configuredDuration }

        // Calculate days with data
        let daysWithData = uniqueDays(for: monthSessions, calendar: calendar)

        return totalFocusTime / Double(daysWithData.count)
    }

    /// Computes the average daily focus time for the current month.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - now: The current date (injectable for testing).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Average daily focus time in seconds for the current month.
    public func currentMonthAverage(
        sessions: [DeepFocusSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeInterval {
        let components = calendar.dateComponents([.year, .month], from: now)
        return monthlyAverage(
            sessions: sessions,
            year: components.year!,
            month: components.month!,
            calendar: calendar
        )
    }

    // MARK: - Month Date Range

    /// Returns the start (inclusive) and end (exclusive) dates of the specified month.
    ///
    /// - Parameters:
    ///   - year: The year.
    ///   - month: The month (1–12).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Tuple of (start of month, start of next month), or nils if invalid.
    public func monthDateRange(
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> (start: Date?, end: Date?) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let monthStart = calendar.date(from: components) else {
            return (nil, nil)
        }

        // Start of next month
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return (nil, nil)
        }

        return (calendar.startOfDay(for: monthStart), calendar.startOfDay(for: monthEnd))
    }

    /// Returns the number of days in the specified month (handles leap years).
    ///
    /// - Parameters:
    ///   - year: The year.
    ///   - month: The month (1–12).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Number of days in the month, or nil if invalid.
    public func daysInMonth(
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> Int? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = calendar.date(from: components) else {
            return nil
        }

        return calendar.range(of: .day, in: .month, for: date)?.count
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
