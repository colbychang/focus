import Testing
import Foundation
@testable import FocusCore

// MARK: - DeepFocusSessionManager Tests

@Suite("DeepFocusSessionManager Tests", .serialized)
@MainActor
struct DeepFocusSessionManagerTests {

    // MARK: - Helpers

    /// Creates a SharedStateService backed by an in-memory UserDefaults.
    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    /// Creates a session manager with a controllable date provider.
    private func makeManager(
        sharedStateService: SharedStateService? = nil,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) -> DeepFocusSessionManager {
        DeepFocusSessionManager(
            sharedStateService: sharedStateService ?? makeSharedStateService(),
            dateProvider: currentDate
        )
    }

    // MARK: - Duration Validation Tests

    @Test("DeepFocusDuration validates minimum 5 minutes")
    func durationValidatesMinimum() {
        #expect(DeepFocusDuration.isValid(minutes: 5) == true)
        #expect(DeepFocusDuration.isValid(minutes: 4) == false)
        #expect(DeepFocusDuration.isValid(minutes: 0) == false)
        #expect(DeepFocusDuration.isValid(minutes: -1) == false)
    }

    @Test("DeepFocusDuration validates maximum 480 minutes")
    func durationValidatesMaximum() {
        #expect(DeepFocusDuration.isValid(minutes: 480) == true)
        #expect(DeepFocusDuration.isValid(minutes: 481) == false)
        #expect(DeepFocusDuration.isValid(minutes: 1000) == false)
    }

    @Test("DeepFocusDuration presets are 30, 60, 90, 120")
    func durationPresetsCorrect() {
        #expect(DeepFocusDuration.presets == [30, 60, 90, 120])
    }

    @Test("All preset durations are valid")
    func presetDurationsAreValid() {
        for preset in DeepFocusDuration.presets {
            #expect(DeepFocusDuration.isValid(minutes: preset))
        }
    }

    // MARK: - Timer Formatting Tests

    @Test("Format MM:SS for durations under 60 minutes")
    func formatMMSS() {
        #expect(DeepFocusTimerFormatter.format(seconds: 0) == "0:00")
        #expect(DeepFocusTimerFormatter.format(seconds: 1) == "0:01")
        #expect(DeepFocusTimerFormatter.format(seconds: 59) == "0:59")
        #expect(DeepFocusTimerFormatter.format(seconds: 60) == "1:00")
        #expect(DeepFocusTimerFormatter.format(seconds: 61) == "1:01")
        #expect(DeepFocusTimerFormatter.format(seconds: 1800) == "30:00")
        #expect(DeepFocusTimerFormatter.format(seconds: 3599) == "59:59")
    }

    @Test("Format H:MM:SS for durations >= 60 minutes")
    func formatHMMSS() {
        #expect(DeepFocusTimerFormatter.format(seconds: 3600) == "1:00:00")
        #expect(DeepFocusTimerFormatter.format(seconds: 3601) == "1:00:01")
        #expect(DeepFocusTimerFormatter.format(seconds: 3661) == "1:01:01")
        #expect(DeepFocusTimerFormatter.format(seconds: 7200) == "2:00:00")
        #expect(DeepFocusTimerFormatter.format(seconds: 28800) == "8:00:00")
    }

    @Test("Format boundary transition from 1:00:00 to 59:59")
    func formatBoundaryTransition() {
        // At exactly 60 minutes
        #expect(DeepFocusTimerFormatter.format(seconds: 3600) == "1:00:00")
        // One second less transitions to MM:SS format
        #expect(DeepFocusTimerFormatter.format(seconds: 3599) == "59:59")
    }

    @Test("Format clamps negative values to 0:00")
    func formatNegativeValues() {
        #expect(DeepFocusTimerFormatter.format(seconds: -1) == "0:00")
        #expect(DeepFocusTimerFormatter.format(seconds: -100) == "0:00")
    }

    @Test("Format edge cases: 0:01 and 0:00")
    func formatEdgeCases() {
        #expect(DeepFocusTimerFormatter.format(seconds: 1) == "0:01")
        #expect(DeepFocusTimerFormatter.format(seconds: 0) == "0:00")
    }

    // MARK: - Session Start Tests

    @Test("Start session with valid duration sets correct state")
    func startSessionSetsState() throws {
        let manager = makeManager()

        try manager.startSession(durationMinutes: 30)

        #expect(manager.sessionStatus == .active)
        #expect(manager.remainingSeconds == 1800) // 30 * 60
        #expect(manager.configuredDurationSeconds == 1800)
        #expect(manager.currentSessionID != nil)
        #expect(manager.sessionStartTime != nil)
        #expect(manager.isSessionRunning == true)
        #expect(manager.bypassCount == 0)
        #expect(manager.breakCount == 0)
        #expect(manager.totalBreakDuration == 0)
    }

    @Test("Start session with preset durations")
    func startSessionWithPresets() throws {
        for preset in DeepFocusDuration.presets {
            let manager = makeManager()
            try manager.startSession(durationMinutes: preset)
            #expect(manager.remainingSeconds == preset * 60)
            #expect(manager.sessionStatus == .active)
        }
    }

    @Test("Start session with custom valid duration")
    func startSessionCustomDuration() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 45)
        #expect(manager.remainingSeconds == 2700) // 45 * 60
    }

    @Test("Cannot start session while one is active")
    func cannotStartWhileActive() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        #expect(throws: DeepFocusSessionManagerError.sessionAlreadyActive) {
            try manager.startSession(durationMinutes: 60)
        }
    }

    @Test("Cannot start with invalid duration - too short")
    func cannotStartTooShort() {
        let manager = makeManager()
        #expect(throws: DeepFocusSessionManagerError.invalidDuration(4)) {
            try manager.startSession(durationMinutes: 4)
        }
    }

    @Test("Cannot start with invalid duration - too long")
    func cannotStartTooLong() {
        let manager = makeManager()
        #expect(throws: DeepFocusSessionManagerError.invalidDuration(481)) {
            try manager.startSession(durationMinutes: 481)
        }
    }

    @Test("Start session marks shared state as active")
    func startSessionMarksSharedStateActive() throws {
        let sharedState = makeSharedStateService()
        let manager = makeManager(sharedStateService: sharedState)

        #expect(sharedState.isSessionActive() == false)

        try manager.startSession(durationMinutes: 30)

        #expect(sharedState.isSessionActive() == true)
    }

    // MARK: - Timer Tick Tests

    @Test("Timer tick decrements remaining seconds by 1")
    func timerTickDecrements() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 5)

        let initial = manager.remainingSeconds
        manager.timerTick()

        #expect(manager.remainingSeconds == initial - 1)
    }

    @Test("Multiple timer ticks decrement correctly")
    func multipleTimerTicks() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 5)

        for _ in 0..<10 {
            manager.timerTick()
        }

        #expect(manager.remainingSeconds == 290) // 300 - 10
    }

    @Test("Timer tick does not decrement below zero - clamp")
    func timerTickClampsAtZero() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 5)

        // Set remaining to 1 directly for testing the boundary
        // Simulate ticks until we get close to zero
        for _ in 0..<300 {
            manager.timerTick()
        }

        #expect(manager.remainingSeconds == 0)
        #expect(manager.sessionStatus == .completed)

        // Additional ticks should not go negative
        manager.timerTick()
        #expect(manager.remainingSeconds == 0)
    }

    @Test("Completion triggers exactly once")
    func completionTriggersOnce() throws {
        var completionCount = 0
        let manager = makeManager()
        manager.onSessionCompleted = { completionCount += 1 }

        try manager.startSession(durationMinutes: 5)

        // Tick down to 0
        for _ in 0..<300 {
            manager.timerTick()
        }

        #expect(completionCount == 1)

        // Additional ticks should not trigger again
        manager.timerTick()
        manager.timerTick()
        #expect(completionCount == 1)
    }

    @Test("Session status transitions to completed when timer reaches 0")
    func sessionCompletesAtZero() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 5)

        for _ in 0..<300 {
            manager.timerTick()
        }

        #expect(manager.sessionStatus == .completed)
        #expect(manager.remainingSeconds == 0)
        #expect(manager.isSessionRunning == false)
    }

    @Test("Timer tick does nothing when status is not active")
    func timerTickIgnoredWhenNotActive() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 5)

        manager.transitionToBreak()
        let remaining = manager.remainingSeconds
        manager.timerTick()

        #expect(manager.remainingSeconds == remaining)
    }

    // MARK: - Background/Foreground Reconciliation Tests

    @Test("Background entry stops timer and persists state")
    func backgroundEntryPersistsState() throws {
        let sharedState = makeSharedStateService()
        let manager = makeManager(sharedStateService: sharedState)

        try manager.startSession(durationMinutes: 30)
        manager.handleBackgroundEntry()

        // State should still be running
        #expect(manager.isSessionRunning == true)

        // Persisted data should exist
        let data = sharedState.getData(forKey: SharedStateKey.deepFocusSessionData.rawValue)
        #expect(data != nil)
    }

    @Test("Foreground entry reconciles elapsed time")
    func foregroundReconciles() throws {
        var currentDate = Date()
        let manager = makeManager(currentDate: { currentDate })

        try manager.startSession(durationMinutes: 30)
        let initialRemaining = manager.remainingSeconds

        // Simulate 60 seconds passing in background
        manager.handleBackgroundEntry()
        currentDate = currentDate.addingTimeInterval(60)
        manager.handleForegroundEntry()

        #expect(manager.remainingSeconds == initialRemaining - 60)
        #expect(manager.sessionStatus == .active)
    }

    @Test("Foreground entry auto-completes if time elapsed")
    func foregroundAutoCompletes() throws {
        var currentDate = Date()
        var completed = false
        let manager = makeManager(currentDate: { currentDate })
        manager.onSessionCompleted = { completed = true }

        try manager.startSession(durationMinutes: 5) // 300 seconds

        manager.handleBackgroundEntry()
        currentDate = currentDate.addingTimeInterval(400) // More than 300s
        manager.handleForegroundEntry()

        #expect(manager.remainingSeconds == 0)
        #expect(manager.sessionStatus == .completed)
        #expect(completed == true)
    }

    @Test("Foreground entry clamps remaining at zero")
    func foregroundClampsAtZero() throws {
        var currentDate = Date()
        let manager = makeManager(currentDate: { currentDate })

        try manager.startSession(durationMinutes: 5) // 300 seconds

        manager.handleBackgroundEntry()
        currentDate = currentDate.addingTimeInterval(600) // Way more than needed
        manager.handleForegroundEntry()

        #expect(manager.remainingSeconds == 0)
    }

    @Test("Background/foreground during break does not tick main timer")
    func backgroundForegroundDuringBreak() throws {
        var currentDate = Date()
        let manager = makeManager(currentDate: { currentDate })

        try manager.startSession(durationMinutes: 30)
        let remaining = manager.remainingSeconds

        manager.transitionToBreak()
        manager.handleBackgroundEntry()
        currentDate = currentDate.addingTimeInterval(120) // 2 minutes pass
        manager.handleForegroundEntry()

        // Timer should NOT have decremented because we're on break
        #expect(manager.remainingSeconds == remaining)
    }

    // MARK: - Session Recovery Tests

    @Test("Recover orphaned session resumes with adjusted time")
    func recoverOrphanedSessionResumes() throws {
        let sharedState = makeSharedStateService()
        var currentDate = Date()

        // First manager: start and persist
        let manager1 = makeManager(sharedStateService: sharedState, currentDate: { currentDate })
        try manager1.startSession(durationMinutes: 30) // 1800s

        // Simulate ticking 100 seconds
        for _ in 0..<100 {
            manager1.timerTick()
        }
        manager1.handleBackgroundEntry() // Persists state

        // Simulate 200 more seconds passing (app terminated)
        currentDate = currentDate.addingTimeInterval(200)

        // New manager: recover
        let manager2 = makeManager(sharedStateService: sharedState, currentDate: { currentDate })
        let recovered = manager2.recoverOrphanedSession()

        #expect(recovered == true)
        #expect(manager2.sessionStatus == .active)
        // 1800 - 100 ticks - 200 elapsed = 1500
        #expect(manager2.remainingSeconds == 1500)
    }

    @Test("Recover orphaned session auto-completes if time fully elapsed")
    func recoverOrphanedAutoCompletes() throws {
        let sharedState = makeSharedStateService()
        var currentDate = Date()
        var completed = false

        let manager1 = makeManager(sharedStateService: sharedState, currentDate: { currentDate })
        try manager1.startSession(durationMinutes: 5) // 300s
        manager1.handleBackgroundEntry()

        // Simulate 400 seconds passing (more than session duration)
        currentDate = currentDate.addingTimeInterval(400)

        let manager2 = makeManager(sharedStateService: sharedState, currentDate: { currentDate })
        manager2.onSessionCompleted = { completed = true }
        let recovered = manager2.recoverOrphanedSession()

        #expect(recovered == true)
        #expect(manager2.sessionStatus == .completed)
        #expect(manager2.remainingSeconds == 0)
        #expect(completed == true)
    }

    @Test("Recover returns false when no persisted session")
    func recoverReturnsFalseWhenNoPersisted() {
        let manager = makeManager()
        let recovered = manager.recoverOrphanedSession()
        #expect(recovered == false)
    }

    @Test("Recover does not recover completed sessions")
    func recoverIgnoresCompletedSessions() throws {
        let sharedState = makeSharedStateService()
        var currentDate = Date()

        let manager1 = makeManager(sharedStateService: sharedState, currentDate: { currentDate })
        try manager1.startSession(durationMinutes: 5)

        // Complete the session
        for _ in 0..<300 {
            manager1.timerTick()
        }

        currentDate = currentDate.addingTimeInterval(10)

        let manager2 = makeManager(sharedStateService: sharedState, currentDate: { currentDate })
        let recovered = manager2.recoverOrphanedSession()

        #expect(recovered == false)
    }

    // MARK: - State Machine Tests

    @Test("Transition to break pauses timer")
    func transitionToBreakPausesTimer() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)
        let remaining = manager.remainingSeconds

        manager.transitionToBreak()

        #expect(manager.sessionStatus == .onBreak)
        #expect(manager.remainingSeconds == remaining)
        #expect(manager.isSessionRunning == true)
    }

    @Test("Resume from break restores active state")
    func resumeFromBreak() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        manager.transitionToBreak()
        manager.resumeFromBreak()

        #expect(manager.sessionStatus == .active)
    }

    @Test("Transition to bypassing keeps timer running")
    func transitionToBypassing() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        manager.transitionToBypassing()

        #expect(manager.sessionStatus == .bypassing)
        #expect(manager.isSessionRunning == true)
    }

    @Test("Resume from bypassing restores active state")
    func resumeFromBypassing() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        manager.transitionToBypassing()
        manager.resumeFromBypassing()

        #expect(manager.sessionStatus == .active)
    }

    @Test("isSessionRunning returns true for active, onBreak, bypassing")
    func isSessionRunningStates() throws {
        let manager = makeManager()

        // Idle
        #expect(manager.isSessionRunning == false)

        // Active
        try manager.startSession(durationMinutes: 30)
        #expect(manager.isSessionRunning == true)

        // On Break
        manager.transitionToBreak()
        #expect(manager.isSessionRunning == true)

        // Resume and transition to bypassing
        manager.resumeFromBreak()
        manager.transitionToBypassing()
        #expect(manager.isSessionRunning == true)
    }

    // MARK: - Abandon Session Tests

    @Test("Abandon session sets status to abandoned")
    func abandonSession() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        manager.abandonSession()

        #expect(manager.sessionStatus == .abandoned)
        #expect(manager.isSessionRunning == false)
    }

    @Test("Abandon session triggers callback")
    func abandonSessionCallback() throws {
        var abandoned = false
        let manager = makeManager()
        manager.onSessionAbandoned = { abandoned = true }

        try manager.startSession(durationMinutes: 30)
        manager.abandonSession()

        #expect(abandoned == true)
    }

    @Test("Abandon session clears shared state")
    func abandonSessionClearsSharedState() throws {
        let sharedState = makeSharedStateService()
        let manager = makeManager(sharedStateService: sharedState)

        try manager.startSession(durationMinutes: 30)
        #expect(sharedState.isSessionActive() == true)

        manager.abandonSession()
        #expect(sharedState.isSessionActive() == false)
    }

    @Test("Abandon has no effect when not running")
    func abandonWhenNotRunning() {
        var abandoned = false
        let manager = makeManager()
        manager.onSessionAbandoned = { abandoned = true }

        manager.abandonSession()
        #expect(abandoned == false)
    }

    // MARK: - Reset Tests

    @Test("Reset to idle clears all state")
    func resetToIdle() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        manager.resetToIdle()

        #expect(manager.sessionStatus == .idle)
        #expect(manager.remainingSeconds == 0)
        #expect(manager.configuredDurationSeconds == 0)
        #expect(manager.currentSessionID == nil)
        #expect(manager.sessionStartTime == nil)
        #expect(manager.isSessionRunning == false)
    }

    @Test("Can start new session after reset")
    func canStartAfterReset() throws {
        let manager = makeManager()
        try manager.startSession(durationMinutes: 30)

        manager.resetToIdle()

        // Should be able to start again
        try manager.startSession(durationMinutes: 60)
        #expect(manager.remainingSeconds == 3600)
    }

    // MARK: - Rapid Start/Stop Tests

    @Test("Rapid start and stop does not corrupt state")
    func rapidStartStop() throws {
        let manager = makeManager()

        // Start and immediately abandon
        try manager.startSession(durationMinutes: 30)
        manager.abandonSession()
        #expect(manager.sessionStatus == .abandoned)

        // Reset and start again
        manager.resetToIdle()
        try manager.startSession(durationMinutes: 60)
        #expect(manager.remainingSeconds == 3600)
        #expect(manager.sessionStatus == .active)

        // Abandon and reset
        manager.abandonSession()
        manager.resetToIdle()
        #expect(manager.sessionStatus == .idle)

        // Start again
        try manager.startSession(durationMinutes: 5)
        #expect(manager.remainingSeconds == 300)
    }

    @Test("Rapid start/stop does not trigger spurious completions")
    func rapidStartStopNoSpuriousCompletion() throws {
        var completionCount = 0
        let manager = makeManager()
        manager.onSessionCompleted = { completionCount += 1 }

        for _ in 0..<5 {
            try manager.startSession(durationMinutes: 30)
            manager.abandonSession()
            manager.resetToIdle()
        }

        #expect(completionCount == 0)
    }

    // MARK: - Formatted Time Tests

    @Test("formattedTimeRemaining returns correct format")
    func formattedTimeRemaining() throws {
        let manager = makeManager()

        // Idle state
        #expect(manager.formattedTimeRemaining == "0:00")

        // 30 min session
        try manager.startSession(durationMinutes: 30)
        #expect(manager.formattedTimeRemaining == "30:00")

        manager.resetToIdle()

        // 120 min session (2 hours)
        try manager.startSession(durationMinutes: 120)
        #expect(manager.formattedTimeRemaining == "2:00:00")
    }

    // MARK: - PersistedSessionState Tests

    @Test("PersistedSessionState encodes and decodes correctly")
    func persistedStateCodable() throws {
        let state = PersistedSessionState(
            sessionID: UUID(),
            startTime: Date(),
            configuredDurationSeconds: 1800,
            remainingSeconds: 1500,
            status: SessionStatus.active.rawValue,
            bypassCount: 2,
            breakCount: 1,
            totalBreakDuration: 120,
            savedAt: Date()
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedSessionState.self, from: data)

        #expect(decoded.sessionID == state.sessionID)
        #expect(decoded.configuredDurationSeconds == 1800)
        #expect(decoded.remainingSeconds == 1500)
        #expect(decoded.status == "active")
        #expect(decoded.bypassCount == 2)
        #expect(decoded.breakCount == 1)
    }

    // MARK: - Error Equatable Tests

    @Test("DeepFocusSessionManagerError equatable")
    func errorEquatable() {
        #expect(DeepFocusSessionManagerError.sessionAlreadyActive == DeepFocusSessionManagerError.sessionAlreadyActive)
        #expect(DeepFocusSessionManagerError.invalidDuration(5) == DeepFocusSessionManagerError.invalidDuration(5))
        #expect(DeepFocusSessionManagerError.invalidDuration(5) != DeepFocusSessionManagerError.invalidDuration(10))
    }

    @Test("DeepFocusSessionManagerError has descriptive messages")
    func errorMessages() {
        #expect(DeepFocusSessionManagerError.sessionAlreadyActive.errorDescription != nil)
        #expect(DeepFocusSessionManagerError.invalidDuration(3).errorDescription?.contains("3") == true)
    }
}
