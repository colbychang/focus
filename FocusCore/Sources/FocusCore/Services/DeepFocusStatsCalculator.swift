import Foundation

// MARK: - DeepFocusStats

/// Computed statistics for deep focus sessions.
public struct DeepFocusStats: Equatable, Sendable {
    /// Total number of deep focus sessions started (all statuses except .idle).
    public let sessionsStarted: Int
    /// Number of sessions that completed successfully.
    public let sessionsCompleted: Int
    /// Total number of bypasses across all sessions.
    public let totalBypasses: Int
    /// Total number of breaks across all sessions.
    public let totalBreaks: Int
    /// Total deep focus time in seconds (completed sessions only).
    /// Abandoned sessions' elapsed time is excluded.
    public let totalFocusTime: TimeInterval
    /// Completion rate as a fraction (0.0–1.0).
    /// Zero if no sessions started.
    public let completionRate: Double

    public init(
        sessionsStarted: Int,
        sessionsCompleted: Int,
        totalBypasses: Int,
        totalBreaks: Int,
        totalFocusTime: TimeInterval,
        completionRate: Double
    ) {
        self.sessionsStarted = sessionsStarted
        self.sessionsCompleted = sessionsCompleted
        self.totalBypasses = totalBypasses
        self.totalBreaks = totalBreaks
        self.totalFocusTime = totalFocusTime
        self.completionRate = completionRate
    }
}

// MARK: - DeepFocusStatsCalculator

/// Calculates statistics for deep focus sessions.
///
/// Rules:
/// - Sessions started: count of sessions with status != .idle.
/// - Sessions completed: count of sessions with status == .completed.
/// - Total bypasses: sum of bypassCount across ALL sessions (started).
/// - Total breaks: sum of breakCount across ALL sessions (started).
/// - Total focus time: sum of configuredDuration for COMPLETED sessions only.
///   Abandoned sessions' elapsed time is NOT included.
/// - Completion rate: sessionsCompleted / sessionsStarted (0.0 if none started).
public struct DeepFocusStatsCalculator: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Calculate

    /// Computes deep focus statistics from the given sessions.
    ///
    /// - Parameter sessions: All deep focus sessions (any status).
    /// - Returns: A `DeepFocusStats` with computed metrics.
    public func calculate(sessions: [DeepFocusSession]) -> DeepFocusStats {
        // Sessions started: all non-idle sessions
        let startedSessions = sessions.filter { $0.status != .idle }
        let sessionsStarted = startedSessions.count

        // Sessions completed
        let completedSessions = startedSessions.filter { $0.status == .completed }
        let sessionsCompleted = completedSessions.count

        // Total bypasses across all started sessions
        let totalBypasses = startedSessions.reduce(0) { $0 + $1.bypassCount }

        // Total breaks across all started sessions
        let totalBreaks = startedSessions.reduce(0) { $0 + $1.breakCount }

        // Total focus time: only completed sessions count
        // Abandoned sessions' elapsed time is excluded
        let totalFocusTime = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }

        // Completion rate
        let completionRate: Double
        if sessionsStarted > 0 {
            completionRate = Double(sessionsCompleted) / Double(sessionsStarted)
        } else {
            completionRate = 0.0
        }

        return DeepFocusStats(
            sessionsStarted: sessionsStarted,
            sessionsCompleted: sessionsCompleted,
            totalBypasses: totalBypasses,
            totalBreaks: totalBreaks,
            totalFocusTime: totalFocusTime,
            completionRate: completionRate
        )
    }
}
