import Foundation

// MARK: - DateRangeFilter

/// Filters sessions by date range with timezone-aware date attribution.
///
/// Rules:
/// - Sessions are attributed to the day of their `startTime` in the device's local timezone.
/// - Midnight-spanning sessions are attributed to the start date (not the end date).
/// - Single-day range returns only sessions starting on that day.
/// - Empty range (no sessions in range) returns empty array.
/// - Timezone-aware grouping uses `TimeZone.current` by default.
/// - Very long sessions (8+ hours) are handled without overflow.
public struct DateRangeFilter: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Filter Sessions

    /// Filters sessions by a date range (inclusive start, exclusive end).
    ///
    /// Sessions are attributed to the day of their `startTime` in the calendar's timezone.
    ///
    /// - Parameters:
    ///   - sessions: All sessions to filter.
    ///   - startDate: The start of the range (inclusive, day granularity).
    ///   - endDate: The end of the range (exclusive, day granularity).
    ///   - calendar: Calendar for timezone-aware date calculations.
    /// - Returns: Sessions whose start date falls within the range.
    public func filterSessions(
        _ sessions: [DeepFocusSession],
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [DeepFocusSession] {
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)

        return sessions.filter { session in
            let sessionDay = calendar.startOfDay(for: session.startTime)
            return sessionDay >= rangeStart && sessionDay < rangeEnd
        }
    }

    /// Filters sessions for a single specific day.
    ///
    /// - Parameters:
    ///   - sessions: All sessions to filter.
    ///   - date: The specific day.
    ///   - calendar: Calendar for timezone-aware date calculations.
    /// - Returns: Sessions whose start date falls on the specified day.
    public func filterSessions(
        _ sessions: [DeepFocusSession],
        on date: Date,
        calendar: Calendar = .current
    ) -> [DeepFocusSession] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return filterSessions(sessions, from: dayStart, to: dayEnd, calendar: calendar)
    }

    // MARK: - Group Sessions by Day

    /// Groups sessions by their attributed date (start date in local timezone).
    ///
    /// - Parameters:
    ///   - sessions: Sessions to group.
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Dictionary of DateComponents (year, month, day) to sessions.
    public func groupByDay(
        _ sessions: [DeepFocusSession],
        calendar: Calendar = .current
    ) -> [DateComponents: [DeepFocusSession]] {
        var grouped: [DateComponents: [DeepFocusSession]] = [:]
        for session in sessions {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: session.startTime)
            grouped[dayComponents, default: []].append(session)
        }
        return grouped
    }

    /// Computes the total focus time per day for a date range.
    /// Only `.completed` sessions are included.
    ///
    /// - Parameters:
    ///   - sessions: All sessions (any status).
    ///   - startDate: Start of range (inclusive).
    ///   - endDate: End of range (exclusive).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Dictionary of DateComponents to total focus time in seconds.
    public func dailyFocusTimes(
        _ sessions: [DeepFocusSession],
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [DateComponents: TimeInterval] {
        let filtered = filterSessions(sessions, from: startDate, to: endDate, calendar: calendar)
        let completed = filtered.filter { $0.status == .completed }
        let grouped = groupByDay(completed, calendar: calendar)

        var result: [DateComponents: TimeInterval] = [:]
        for (day, daySessions) in grouped {
            result[day] = daySessions.reduce(0.0) { $0 + $1.configuredDuration }
        }
        return result
    }
}
