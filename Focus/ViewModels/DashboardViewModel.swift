import Foundation
import SwiftData
import FocusCore

// MARK: - DashboardViewModel

/// ViewModel for the analytics dashboard.
/// Computes summary statistics from SwiftData session records.
///
/// Properties:
/// - `totalFocusTime`: Sum of configured durations for completed sessions only (abandoned excluded)
/// - `sessionsCompleted`: Count of completed sessions
/// - `currentStreak`: Consecutive days with at least one completed session
/// - `isEmpty`: Whether there are no sessions at all
///
/// Uses `@Observable` (Observation framework) for reactive updates.
@MainActor
@Observable
public final class DashboardViewModel {

    // MARK: - Published Properties

    /// Total focus time in seconds (completed sessions only, abandoned excluded).
    public private(set) var totalFocusTime: TimeInterval = 0

    /// Number of completed sessions.
    public private(set) var sessionsCompleted: Int = 0

    /// Current streak of consecutive days with at least one completed session.
    public private(set) var currentStreak: Int = 0

    /// Whether there are no sessions at all (empty state).
    public private(set) var isEmpty: Bool = true

    /// All sessions for display and history (sorted by startTime descending).
    public private(set) var allSessions: [DeepFocusSession] = []

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let streakCalculator: StreakCalculator
    private let dateProvider: () -> Date

    // MARK: - Initialization

    /// Creates a DashboardViewModel.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData model context to query sessions from.
    ///   - streakCalculator: The streak calculator instance.
    ///   - dateProvider: A closure providing the current date (injectable for testing).
    public init(
        modelContext: ModelContext,
        streakCalculator: StreakCalculator = StreakCalculator(),
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.streakCalculator = streakCalculator
        self.dateProvider = dateProvider
        refresh()
    }

    // MARK: - Refresh

    /// Refreshes all computed values from SwiftData.
    /// Called automatically on init, and should be called after new sessions are added.
    public func refresh() {
        // Fetch all sessions sorted by startTime descending
        var descriptor = FetchDescriptor<DeepFocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = nil

        do {
            let sessions = try modelContext.fetch(descriptor)
            allSessions = sessions

            // Empty state
            isEmpty = sessions.isEmpty

            // Completed sessions only
            let completedSessions = sessions.filter { $0.status == .completed }

            // Total focus time: sum of configured durations for completed sessions
            totalFocusTime = completedSessions.reduce(0) { $0 + $1.configuredDuration }

            // Sessions completed count
            sessionsCompleted = completedSessions.count

            // Current streak
            currentStreak = streakCalculator.currentStreak(
                sessions: sessions,
                now: dateProvider()
            )
        } catch {
            allSessions = []
            isEmpty = true
            totalFocusTime = 0
            sessionsCompleted = 0
            currentStreak = 0
        }
    }

    // MARK: - Formatting Helpers

    /// Formats a time interval as a human-readable string.
    /// Examples: "0m", "45m", "1h 30m", "2h 0m"
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formats a date for display in session history rows.
    /// Shows relative date for recent dates, otherwise full date.
    public static func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Returns a status label and color for a session status.
    public static func statusInfo(for status: SessionStatus) -> (label: String, colorName: String) {
        switch status {
        case .completed:
            return ("Completed", "green")
        case .abandoned:
            return ("Abandoned", "red")
        case .active:
            return ("Active", "blue")
        case .onBreak:
            return ("On Break", "orange")
        case .bypassing:
            return ("Bypassing", "yellow")
        case .idle:
            return ("Idle", "gray")
        }
    }

    /// Returns a display label for the mode type of a session.
    public static func modeTypeLabel(for session: DeepFocusSession) -> String {
        if session.focusMode != nil {
            return session.focusMode?.name ?? "Focus Mode"
        }
        return "Deep Focus"
    }

    /// Formats duration in H:MM:SS or M:SS format.
    public static func formatDurationDetailed(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
