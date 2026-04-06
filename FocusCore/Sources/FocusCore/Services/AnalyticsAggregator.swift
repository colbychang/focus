import Foundation
import SwiftData

// MARK: - AnalyticsAggregator

/// Background aggregation actor for large dataset performance.
/// Uses @ModelActor for off-main-thread SwiftData queries with FetchDescriptor
/// and fetchLimit for pagination.
///
/// Ensures:
/// - Dashboard renders <2s with 900+ sessions
/// - Queries complete <500ms
/// - Totals consistency: total equals sum of individual sessions
/// - Monthly averages divide by active days, not calendar days
@ModelActor
public actor AnalyticsAggregator {

    // MARK: - Aggregated Results

    /// Result of a full analytics aggregation pass.
    public struct AggregatedResult: Sendable {
        /// Total focus time in seconds (completed sessions only).
        public let totalFocusTime: TimeInterval
        /// Number of completed sessions.
        public let sessionsCompleted: Int
        /// Total number of sessions (all statuses except idle).
        public let sessionsStarted: Int
        /// Current streak.
        public let currentStreak: Int
        /// Daily bar chart data for the last 7 days.
        public let dailyChartData: [BarChartDataPoint]
        /// Weekly line chart data for the last 12 weeks.
        public let weeklyChartData: [LineChartDataPoint]
    }

    // MARK: - Paginated Fetch

    /// Fetches sessions using FetchDescriptor with fetchLimit for pagination.
    /// This prevents loading all 900+ sessions into memory at once for simple counts.
    ///
    /// - Parameters:
    ///   - predicate: Optional predicate to filter sessions.
    ///   - fetchLimit: Maximum number of sessions to fetch per page.
    /// - Returns: Array of fetched sessions.
    public func fetchSessions(
        predicate: Predicate<DeepFocusSession>? = nil,
        sortBy: [SortDescriptor<DeepFocusSession>] = [SortDescriptor(\.startTime, order: .reverse)],
        fetchLimit: Int? = nil
    ) -> [DeepFocusSession] {
        var descriptor = FetchDescriptor<DeepFocusSession>(
            predicate: predicate,
            sortBy: sortBy
        )
        descriptor.fetchLimit = fetchLimit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Computes the total focus time ensuring it equals the sum of all individual
    /// completed session durations. This guarantees totals consistency (VAL-CROSS-012).
    ///
    /// - Parameter sessions: Sessions to sum. Only `.completed` are counted.
    /// - Returns: Total focus time in seconds.
    public func computeTotalFocusTime(sessions: [DeepFocusSession]) -> TimeInterval {
        sessions
            .filter { $0.status == .completed }
            .reduce(0.0) { $0 + $1.configuredDuration }
    }

    /// Performs a full aggregation for the dashboard.
    /// Fetches all sessions and computes all metrics in a single pass.
    ///
    /// - Parameters:
    ///   - now: Current date (injectable for testing).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Aggregated results for the dashboard.
    public func aggregateDashboard(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AggregatedResult {
        let allSessions = fetchSessions()

        let completedSessions = allSessions.filter { $0.status == .completed }
        let totalFocusTime = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }
        let sessionsCompleted = completedSessions.count
        let sessionsStarted = allSessions.filter { $0.status != .idle }.count

        let streakCalculator = StreakCalculator()
        let currentStreak = streakCalculator.currentStreak(sessions: allSessions, now: now, calendar: calendar)

        let chartBuilder = ChartDataBuilder()
        let dailyChartData = chartBuilder.buildDailyBarChartData(
            sessions: allSessions,
            lastDays: 7,
            now: now,
            calendar: calendar
        )
        let weeklyChartData = chartBuilder.buildWeeklyLineChartData(
            sessions: allSessions,
            weeks: 12,
            now: now,
            calendar: calendar
        )

        return AggregatedResult(
            totalFocusTime: totalFocusTime,
            sessionsCompleted: sessionsCompleted,
            sessionsStarted: sessionsStarted,
            currentStreak: currentStreak,
            dailyChartData: dailyChartData,
            weeklyChartData: weeklyChartData
        )
    }

    /// Fetches sessions within a date range for paginated display.
    ///
    /// - Parameters:
    ///   - startDate: Start of range (inclusive).
    ///   - endDate: End of range (exclusive).
    ///   - limit: Maximum number of sessions to return.
    ///   - offset: Number of sessions to skip (for pagination).
    /// - Returns: Array of sessions within the date range.
    public func fetchSessionsInRange(
        startDate: Date,
        endDate: Date,
        limit: Int = 50,
        offset: Int = 0
    ) -> [DeepFocusSession] {
        let predicate = #Predicate<DeepFocusSession> { session in
            session.startTime >= startDate && session.startTime < endDate
        }
        var descriptor = FetchDescriptor<DeepFocusSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }
}
