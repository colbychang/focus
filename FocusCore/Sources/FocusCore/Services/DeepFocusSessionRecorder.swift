import Foundation
import SwiftData

// MARK: - DeepFocusSessionRecorder

/// Records deep focus session statistics into SwiftData.
///
/// On session completion or abandonment, creates a `DeepFocusSession` record
/// with: start time, configured duration, actual elapsed time, status,
/// bypass count, break count, and total break duration.
///
/// Abandoned sessions record status = `.abandoned` with completedFocusTime = 0
/// (remainingSeconds set to configuredDuration, meaning no credit given).
///
/// This service is called by the session orchestration layer when the session
/// state machine transitions to `.completed` or `.abandoned`.
public final class DeepFocusSessionRecorder: @unchecked Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Record Completed Session

    /// Records a completed deep focus session.
    /// Called when the timer reaches 0 and status transitions to `.completed`.
    ///
    /// - Parameters:
    ///   - sessionID: The unique session identifier.
    ///   - startTime: When the session started.
    ///   - configuredDuration: The total configured duration in seconds.
    ///   - elapsedTime: The actual elapsed focus time in seconds (configuredDuration for completed sessions).
    ///   - bypassCount: Number of bypasses used during the session.
    ///   - breakCount: Number of breaks taken during the session.
    ///   - totalBreakDuration: Total break time in seconds.
    ///   - modelContext: The SwiftData model context to insert the record into.
    @MainActor
    public func recordCompletedSession(
        sessionID: UUID,
        startTime: Date,
        configuredDuration: TimeInterval,
        elapsedTime: TimeInterval,
        bypassCount: Int,
        breakCount: Int,
        totalBreakDuration: TimeInterval,
        modelContext: ModelContext
    ) {
        let session = DeepFocusSession(
            id: sessionID,
            startTime: startTime,
            configuredDuration: configuredDuration,
            remainingSeconds: 0,
            status: .completed,
            bypassCount: bypassCount,
            breakCount: breakCount,
            totalBreakDuration: totalBreakDuration
        )
        modelContext.insert(session)
        try? modelContext.save()
    }

    // MARK: - Record Abandoned Session

    /// Records an abandoned deep focus session.
    /// Called when the user confirms the two-step exit flow.
    /// Abandoned sessions record `completedFocusTime = 0` — the remaining seconds
    /// is set to the configured duration, indicating no credit for focus time.
    ///
    /// - Parameters:
    ///   - sessionID: The unique session identifier.
    ///   - startTime: When the session started.
    ///   - configuredDuration: The total configured duration in seconds.
    ///   - remainingSeconds: How many seconds were left when abandoned.
    ///   - bypassCount: Number of bypasses used during the session.
    ///   - breakCount: Number of breaks taken during the session.
    ///   - totalBreakDuration: Total break time in seconds.
    ///   - modelContext: The SwiftData model context to insert the record into.
    @MainActor
    public func recordAbandonedSession(
        sessionID: UUID,
        startTime: Date,
        configuredDuration: TimeInterval,
        remainingSeconds: TimeInterval,
        bypassCount: Int,
        breakCount: Int,
        totalBreakDuration: TimeInterval,
        modelContext: ModelContext
    ) {
        let session = DeepFocusSession(
            id: sessionID,
            startTime: startTime,
            configuredDuration: configuredDuration,
            remainingSeconds: remainingSeconds,
            status: .abandoned,
            bypassCount: bypassCount,
            breakCount: breakCount,
            totalBreakDuration: totalBreakDuration
        )
        modelContext.insert(session)
        try? modelContext.save()
    }

    // MARK: - Record from Session Manager

    /// Convenience method that records a session from the current state of a `DeepFocusSessionManager`.
    /// Determines completed vs abandoned based on the session status.
    ///
    /// - Parameters:
    ///   - sessionManager: The session manager containing the session data.
    ///   - modelContext: The SwiftData model context to insert the record into.
    /// - Returns: The created `DeepFocusSession`, or `nil` if the session can't be recorded.
    @MainActor
    @discardableResult
    public func recordSession(
        from sessionManager: DeepFocusSessionManager,
        modelContext: ModelContext
    ) -> DeepFocusSession? {
        guard let sessionID = sessionManager.currentSessionID,
              let startTime = sessionManager.sessionStartTime else {
            return nil
        }

        let configuredDuration = TimeInterval(sessionManager.configuredDurationSeconds)

        switch sessionManager.sessionStatus {
        case .completed:
            let session = DeepFocusSession(
                id: sessionID,
                startTime: startTime,
                configuredDuration: configuredDuration,
                remainingSeconds: 0,
                status: .completed,
                bypassCount: sessionManager.bypassCount,
                breakCount: sessionManager.breakCount,
                totalBreakDuration: sessionManager.totalBreakDuration
            )
            modelContext.insert(session)
            try? modelContext.save()
            return session

        case .abandoned:
            let session = DeepFocusSession(
                id: sessionID,
                startTime: startTime,
                configuredDuration: configuredDuration,
                remainingSeconds: configuredDuration, // completedFocusTime = 0
                status: .abandoned,
                bypassCount: sessionManager.bypassCount,
                breakCount: sessionManager.breakCount,
                totalBreakDuration: sessionManager.totalBreakDuration
            )
            modelContext.insert(session)
            try? modelContext.save()
            return session

        default:
            return nil
        }
    }
}
