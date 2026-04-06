import Foundation

// MARK: - StreakCalculator

/// Calculates the current streak of consecutive days with at least one completed session.
///
/// Rules:
/// - A day counts as "active" if it has at least 1 completed session (status == `.completed`)
/// - Abandoned sessions do NOT count toward the streak
/// - Multiple sessions in one day = 1 active day
/// - Gaps of one or more days reset the streak
/// - Grace period: if today has no session yet, the streak is counted from yesterday backward
///   (today doesn't break the streak until midnight passes without a session)
/// - Sessions are attributed to the day of their `startTime` (device local time)
public struct StreakCalculator: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Calculate Streak

    /// Computes the current streak of consecutive days with completed sessions.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - now: The current date/time (injectable for testing).
    ///   - calendar: The calendar to use for date calculations (injectable for testing).
    /// - Returns: The number of consecutive days in the current streak.
    public func currentStreak(
        sessions: [DeepFocusSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        // Filter to completed sessions only
        let completedSessions = sessions.filter { $0.status == .completed }

        guard !completedSessions.isEmpty else { return 0 }

        // Build set of active days (unique days with at least one completed session)
        var activeDays = Set<DateComponents>()
        for session in completedSessions {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: session.startTime)
            activeDays.insert(dayComponents)
        }

        let today = calendar.dateComponents([.year, .month, .day], from: now)

        // Determine the starting point:
        // If today has a session, start from today.
        // Otherwise, start from yesterday (grace period for current day).
        let hasTodaySession = activeDays.contains(today)

        let startDate: Date
        if hasTodaySession {
            startDate = calendar.startOfDay(for: now)
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
                return 0
            }
            startDate = yesterday
        }

        // Count consecutive days backward from startDate
        var streak = 0
        var checkDate = startDate

        while true {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)
            if activeDays.contains(dayComponents) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }
}
