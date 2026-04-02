import Testing
import Foundation
@testable import FocusCore

// MARK: - BypassFlowManager Tests

@Suite("BypassFlowManager Tests", .serialized)
@MainActor
struct BypassFlowManagerTests {

    // MARK: - Helpers

    /// Creates a SharedStateService backed by an in-memory UserDefaults.
    private func makeSharedStateService(dateProvider: @escaping () -> Date = { Date() }) -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults, dateProvider: dateProvider)
    }

    /// Creates the full test setup: bypass manager, session manager, blocking service, and mocks.
    private func makeTestSetup(
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) -> (
        bypassManager: BypassFlowManager,
        sessionManager: DeepFocusSessionManager,
        blockingService: DeepFocusBlockingService,
        mockShieldService: MockShieldService,
        sharedState: SharedStateService
    ) {
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: dateProvider
        )
        let bypassManager = BypassFlowManager(
            blockingService: blockingService,
            sessionManager: sessionManager,
            sharedStateService: sharedState,
            dateProvider: dateProvider
        )
        return (bypassManager, sessionManager, blockingService, mockShield, sharedState)
    }

    /// Helper to start a session and apply blocking for test scenarios.
    private func startSessionWithBlocking(
        sessionManager: DeepFocusSessionManager,
        blockingService: DeepFocusBlockingService,
        durationMinutes: Int = 30,
        allowedTokens: Set<Data>? = nil
    ) throws {
        try sessionManager.startSession(durationMinutes: durationMinutes)
        blockingService.applyBlocking(allowedTokens: allowedTokens)
    }

    // MARK: - Basic Countdown Tests

    @Test("Request bypass starts 60-second countdown")
    func requestBypassStartsCountdown() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        #expect(bypass.isCountdownActive == true)
        #expect(bypass.countdownSecondsRemaining == 60)
        #expect(bypass.currentAppTokenData == appToken)
    }

    @Test("Countdown tick decrements seconds remaining")
    func countdownTickDecrements() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        bypass.countdownTick()
        #expect(bypass.countdownSecondsRemaining == 59)

        bypass.countdownTick()
        #expect(bypass.countdownSecondsRemaining == 58)
    }

    @Test("Countdown progression from 60 to 0 completes bypass")
    func countdownProgressionToZero() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var grantedApp: Data?
        bypass.onBypassGranted = { grantedApp = $0 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Tick 60 times
        for _ in 0..<60 {
            bypass.countdownTick()
        }

        #expect(bypass.isBypassActive == true)
        #expect(bypass.isCountdownActive == false)
        #expect(grantedApp == appToken)
    }

    @Test("Countdown does not go negative — clamps at 0")
    func countdownClampsAtZero() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Tick 65 times (more than needed)
        for _ in 0..<65 {
            bypass.countdownTick()
        }

        #expect(bypass.countdownSecondsRemaining == 0)
        #expect(bypass.isBypassActive == true)
    }

    @Test("Bypass granted callback fires exactly once")
    func bypassGrantedFiresOnce() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var grantCount = 0
        bypass.onBypassGranted = { _ in grantCount += 1 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Tick past completion
        for _ in 0..<65 {
            bypass.countdownTick()
        }

        #expect(grantCount == 1)
    }

    // MARK: - Single-App Unlock Tests

    @Test("After countdown, only the requested app is added to exception set")
    func singleAppUnlock() throws {
        let (bypass, session, blocking, mockShield, _) = makeTestSetup()
        let initialTokens: Set<Data> = [Data([10, 20]), Data([30, 40])]
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, allowedTokens: initialTokens)

        let appToken = Data([50, 60])
        try bypass.requestBypass(forApp: appToken)

        // Complete the countdown
        for _ in 0..<60 {
            bypass.countdownTick()
        }

        // Verify the shield was updated with the additional app
        let lastCall = mockShield.applyShieldsCalls.last!
        let expectedTokens = initialTokens.union([appToken])
        #expect(lastCall.applications == expectedTokens)
        #expect(lastCall.categories == expectedTokens)
        #expect(lastCall.webDomains == expectedTokens)
    }

    @Test("App remains blocked during countdown — no shield changes until countdown completes")
    func appBlockedDuringCountdown() throws {
        let (bypass, session, blocking, mockShield, _) = makeTestSetup()
        let initialTokens: Set<Data> = [Data([10, 20])]
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, allowedTokens: initialTokens)

        let callCountAfterSetup = mockShield.applyShieldsCalls.count

        let appToken = Data([50, 60])
        try bypass.requestBypass(forApp: appToken)

        // Tick 30 seconds (halfway through countdown)
        for _ in 0..<30 {
            bypass.countdownTick()
        }

        // No new shield calls should have been made during countdown
        #expect(mockShield.applyShieldsCalls.count == callCountAfterSetup)
    }

    // MARK: - Non-Skippability Tests

    @Test("Countdown cannot be skipped — no fast-forward method exists")
    func countdownCannotBeSkipped() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // After 10 ticks, should still have 50 seconds remaining
        for _ in 0..<10 {
            bypass.countdownTick()
        }

        #expect(bypass.countdownSecondsRemaining == 50)
        #expect(bypass.isCountdownActive == true)
        #expect(bypass.isBypassActive == false)
    }

    // MARK: - Background/Foreground Reconciliation Tests

    @Test("Background/foreground does not reset countdown — uses wall-clock reconciliation")
    func backgroundForegroundWallClockReconciliation() throws {
        var currentDate = Date()
        let (bypass, session, blocking, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Simulate 30 seconds of countdown ticks
        for _ in 0..<10 {
            bypass.countdownTick()
        }
        #expect(bypass.countdownSecondsRemaining == 50)

        // Simulate going to background
        bypass.handleBackgroundEntry()

        // Simulate 20 seconds passing in background
        currentDate = currentDate.addingTimeInterval(20)

        // Foreground entry should reconcile using wall clock
        bypass.handleForegroundEntry()

        // Should have: 60 - 20 elapsed since start = 40 remaining
        // (wall clock from countdown start, not from ticks)
        #expect(bypass.countdownSecondsRemaining == 40)
        #expect(bypass.isCountdownActive == true)
    }

    @Test("Background/foreground with full elapsed time completes bypass")
    func backgroundForegroundAutoCompletes() throws {
        var currentDate = Date()
        let (bypass, session, blocking, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var grantedApp: Data?
        bypass.onBypassGranted = { grantedApp = $0 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        bypass.handleBackgroundEntry()

        // 90 seconds pass in background (more than 60)
        currentDate = currentDate.addingTimeInterval(90)

        bypass.handleForegroundEntry()

        #expect(bypass.isBypassActive == true)
        #expect(bypass.isCountdownActive == false)
        #expect(grantedApp == appToken)
    }

    // MARK: - Timer Independence Tests

    @Test("Main deep focus timer continues during bypass — session transitions to .bypassing")
    func mainTimerContinuesDuringBypass() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let initialRemaining = session.remainingSeconds

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Session should transition to bypassing
        #expect(session.sessionStatus == .bypassing)
        #expect(session.isSessionRunning == true)

        // Timer continues during bypass — timerTick should decrement
        session.timerTick()
        #expect(session.remainingSeconds == initialRemaining - 1)
        #expect(session.sessionStatus == .bypassing)
    }

    @Test("Bypass does NOT pause main deep focus timer — background/foreground reconciles")
    func bypassDoesNotPauseMainTimer() throws {
        var currentDate = Date()
        let (bypass, session, blocking, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        #expect(session.sessionStatus == .bypassing)
        let remaining = session.remainingSeconds

        // Simulate background/foreground with 120 seconds passing
        session.handleBackgroundEntry()
        currentDate = currentDate.addingTimeInterval(120)
        session.handleForegroundEntry()

        // Timer should have decremented by 120 seconds (bypass does NOT pause)
        #expect(session.remainingSeconds == remaining - 120)
        #expect(session.isSessionRunning == true)
    }

    // MARK: - Countdown Replacement Tests

    @Test("New bypass request during active countdown cancels old and starts fresh 60s")
    func countdownReplacement() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let app1Token = Data([1, 2, 3])
        let app2Token = Data([4, 5, 6])

        // Start first countdown
        try bypass.requestBypass(forApp: app1Token)

        // Tick 20 seconds
        for _ in 0..<20 {
            bypass.countdownTick()
        }
        #expect(bypass.countdownSecondsRemaining == 40)

        // Start new countdown (replaces old)
        try bypass.requestBypass(forApp: app2Token)

        // Should be back at 60 seconds for the new app
        #expect(bypass.countdownSecondsRemaining == 60)
        #expect(bypass.currentAppTokenData == app2Token)
        #expect(bypass.isCountdownActive == true)
    }

    @Test("New bypass request during active bypass starts countdown for new app")
    func newBypassDuringActiveBypass() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let app1Token = Data([1, 2, 3])
        let app2Token = Data([4, 5, 6])

        // Complete first bypass
        try bypass.requestBypass(forApp: app1Token)
        for _ in 0..<60 {
            bypass.countdownTick()
        }
        #expect(bypass.isBypassActive == true)
        #expect(bypass.currentAppTokenData == app1Token)

        // Request new bypass
        try bypass.requestBypass(forApp: app2Token)

        // Should be in countdown for new app
        #expect(bypass.isCountdownActive == true)
        #expect(bypass.currentAppTokenData == app2Token)
        #expect(bypass.countdownSecondsRemaining == 60)
    }

    @Test("Previous bypass is revoked when new bypass completes")
    func previousBypassRevokedOnNewCompletion() throws {
        let (bypass, session, blocking, mockShield, _) = makeTestSetup()
        let initialTokens: Set<Data> = [Data([10, 20])]
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, allowedTokens: initialTokens)

        var revokedApps: [Data] = []
        bypass.onBypassRevoked = { revokedApps.append($0) }

        let app1Token = Data([1, 2, 3])
        let app2Token = Data([4, 5, 6])

        // Complete first bypass
        try bypass.requestBypass(forApp: app1Token)
        for _ in 0..<60 {
            bypass.countdownTick()
        }
        #expect(bypass.isBypassActive == true)

        // Now request second bypass — the old one should be revoked on completion
        try bypass.requestBypass(forApp: app2Token)
        for _ in 0..<60 {
            bypass.countdownTick()
        }

        // After second bypass completes, first should be revoked
        // The token set should contain initial tokens + app2 (but NOT app1)
        let lastCall = mockShield.applyShieldsCalls.last!
        let expectedTokens = initialTokens.union([app2Token])
        #expect(lastCall.applications == expectedTokens)
    }

    // MARK: - Break/Bypass Interaction Tests

    @Test("Bypass during break is rejected")
    func bypassDuringBreakRejected() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        // Put session on break
        session.transitionToBreak()

        let appToken = Data([1, 2, 3])
        #expect(throws: BypassFlowError.bypassDuringBreakRejected) {
            try bypass.requestBypass(forApp: appToken)
        }
    }

    @Test("Break during bypass countdown cancels bypass")
    func breakDuringCountdownCancelsIt() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var countdownCancelled = false
        bypass.onCountdownCancelled = { countdownCancelled = true }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Tick a bit
        for _ in 0..<10 {
            bypass.countdownTick()
        }

        // Break starts
        bypass.handleBreakStarted()

        #expect(bypass.bypassState == .idle)
        #expect(bypass.isCountdownActive == false)
        #expect(countdownCancelled == true)
    }

    @Test("Break with active bypass revokes it")
    func breakWithActiveBypassRevokesIt() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var revokedApp: Data?
        bypass.onBypassRevoked = { revokedApp = $0 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Complete the countdown
        for _ in 0..<60 {
            bypass.countdownTick()
        }
        #expect(bypass.isBypassActive == true)

        // Break starts — should revoke bypass
        bypass.handleBreakStarted()

        #expect(bypass.bypassState == .idle)
        #expect(bypass.isBypassActive == false)
        #expect(revokedApp == appToken)
    }

    @Test("After break, user must re-request bypass")
    func afterBreakMustReRequestBypass() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Complete countdown
        for _ in 0..<60 {
            bypass.countdownTick()
        }
        #expect(bypass.isBypassActive == true)

        // Break starts — revokes bypass
        bypass.handleBreakStarted()
        #expect(bypass.bypassState == .idle)

        // After break, session resumes to active
        session.resumeFromBypassing()
        #expect(session.sessionStatus == .active)

        // User must re-request — bypass is not auto-restored
        #expect(bypass.isBypassActive == false)
        #expect(bypass.isCountdownActive == false)
    }

    // MARK: - Session Completion Cleanup Tests

    @Test("Session completion cancels active countdown")
    func sessionCompletionCancelsCountdown() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Tick 20 seconds
        for _ in 0..<20 {
            bypass.countdownTick()
        }
        #expect(bypass.isCountdownActive == true)

        // Session completes
        bypass.handleSessionCompleted()

        #expect(bypass.bypassState == .idle)
        #expect(bypass.isCountdownActive == false)
    }

    @Test("Session completion revokes active bypass")
    func sessionCompletionRevokesActiveBypass() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var revokedApp: Data?
        bypass.onBypassRevoked = { revokedApp = $0 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Complete countdown
        for _ in 0..<60 {
            bypass.countdownTick()
        }
        #expect(bypass.isBypassActive == true)

        // Session completes
        bypass.handleSessionCompleted()

        #expect(bypass.bypassState == .idle)
        #expect(bypass.isBypassActive == false)
        #expect(revokedApp == appToken)
    }

    @Test("Session completion clears shared state")
    func sessionCompletionClearsSharedState() throws {
        let (bypass, session, blocking, _, sharedState) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        #expect(sharedState.isBypassActive() == true)

        bypass.handleSessionCompleted()

        #expect(sharedState.isBypassActive() == false)
    }

    @Test("Session completion with no bypass state is a no-op")
    func sessionCompletionNoBypassIsNoop() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        // No bypass requested, just complete
        bypass.handleSessionCompleted()

        #expect(bypass.bypassState == .idle)
    }

    // MARK: - Error Handling Tests

    @Test("Bypass rejected when no active session")
    func bypassRejectedNoSession() throws {
        let (bypass, _, _, _, _) = makeTestSetup()

        let appToken = Data([1, 2, 3])
        #expect(throws: BypassFlowError.noActiveSession) {
            try bypass.requestBypass(forApp: appToken)
        }
    }

    @Test("Bypass rejected when session is completed")
    func bypassRejectedCompletedSession() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, durationMinutes: 5)

        // Complete the session
        for _ in 0..<300 {
            session.timerTick()
        }
        #expect(session.sessionStatus == .completed)

        let appToken = Data([1, 2, 3])
        #expect(throws: BypassFlowError.noActiveSession) {
            try bypass.requestBypass(forApp: appToken)
        }
    }

    @Test("Bypass rejected when session is abandoned")
    func bypassRejectedAbandonedSession() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        session.abandonSession()

        let appToken = Data([1, 2, 3])
        #expect(throws: BypassFlowError.noActiveSession) {
            try bypass.requestBypass(forApp: appToken)
        }
    }

    // MARK: - Cancel Tests

    @Test("Cancel countdown dismisses countdown")
    func cancelDismissesCountdown() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var cancelled = false
        bypass.onCountdownCancelled = { cancelled = true }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)
        #expect(bypass.isCountdownActive == true)

        bypass.cancelBypass()

        #expect(bypass.bypassState == .idle)
        #expect(bypass.isCountdownActive == false)
        #expect(cancelled == true)
    }

    @Test("Cancel active bypass revokes it")
    func cancelActiveBypassRevokes() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var revokedApp: Data?
        bypass.onBypassRevoked = { revokedApp = $0 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Complete countdown
        for _ in 0..<60 {
            bypass.countdownTick()
        }

        bypass.cancelBypass()

        #expect(bypass.bypassState == .idle)
        #expect(revokedApp == appToken)
    }

    @Test("Cancel when idle is a no-op")
    func cancelWhenIdleIsNoop() throws {
        let (bypass, _, _, _, _) = makeTestSetup()

        bypass.cancelBypass() // Should not crash
        #expect(bypass.bypassState == .idle)
    }

    @Test("Cancel restores session to active state")
    func cancelRestoresActiveState() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)
        #expect(session.sessionStatus == .bypassing)

        bypass.cancelBypass()

        #expect(session.sessionStatus == .active)
    }

    // MARK: - Bypass Count Tests

    @Test("Bypass completion increments bypass count on session manager")
    func bypassCompletionIncrementsCount() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        #expect(session.bypassCount == 0)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        for _ in 0..<60 {
            bypass.countdownTick()
        }

        #expect(session.bypassCount == 1)
    }

    @Test("Multiple bypass completions increment count correctly")
    func multipleBypassesIncrementCount() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        // First bypass
        try bypass.requestBypass(forApp: Data([1, 2, 3]))
        for _ in 0..<60 { bypass.countdownTick() }
        #expect(session.bypassCount == 1)

        // Second bypass (replaces first)
        try bypass.requestBypass(forApp: Data([4, 5, 6]))
        for _ in 0..<60 { bypass.countdownTick() }
        #expect(session.bypassCount == 2)
    }

    // MARK: - Reset Tests

    @Test("Reset to idle clears all bypass state")
    func resetClearsAllState() throws {
        let (bypass, session, blocking, _, sharedState) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        bypass.resetToIdle()

        #expect(bypass.bypassState == .idle)
        #expect(bypass.isCountdownActive == false)
        #expect(bypass.isBypassActive == false)
        #expect(bypass.countdownSecondsRemaining == 0)
        #expect(bypass.currentAppTokenData == nil)
        #expect(sharedState.isBypassActive() == false)
    }

    // MARK: - BypassFlowError Tests

    @Test("BypassFlowError has descriptive messages")
    func errorMessages() {
        #expect(BypassFlowError.bypassDuringBreakRejected.errorDescription != nil)
        #expect(BypassFlowError.noActiveSession.errorDescription != nil)
        #expect(BypassFlowError.countdownAlreadyActive.errorDescription != nil)
    }

    @Test("BypassFlowError equatable")
    func errorEquatable() {
        #expect(BypassFlowError.bypassDuringBreakRejected == BypassFlowError.bypassDuringBreakRejected)
        #expect(BypassFlowError.noActiveSession == BypassFlowError.noActiveSession)
        #expect(BypassFlowError.bypassDuringBreakRejected != BypassFlowError.noActiveSession)
    }

    // MARK: - BypassState Tests

    @Test("BypassState equatable")
    func bypassStateEquatable() {
        let token = Data([1, 2, 3])
        #expect(BypassState.idle == BypassState.idle)
        #expect(BypassState.countdown(appTokenData: token, secondsRemaining: 30) == BypassState.countdown(appTokenData: token, secondsRemaining: 30))
        #expect(BypassState.active(appTokenData: token) == BypassState.active(appTokenData: token))
        #expect(BypassState.idle != BypassState.active(appTokenData: token))
    }

    // MARK: - Edge Case: Session completion during bypass countdown (VAL-DEEP-013)

    @Test("Session completion during bypass countdown cleans up properly")
    func sessionCompletionDuringCountdown() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, durationMinutes: 5)

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Tick 20 seconds of countdown
        for _ in 0..<20 {
            bypass.countdownTick()
        }
        #expect(bypass.isCountdownActive == true)

        // Session completes (simulating timer reaching 0)
        bypass.handleSessionCompleted()

        // All bypass state should be cleaned up
        #expect(bypass.bypassState == .idle)
        #expect(bypass.isCountdownActive == false)
        #expect(bypass.isBypassActive == false)
    }

    @Test("Session completion during active bypass cleans up and records")
    func sessionCompletionDuringActiveBypass() throws {
        let (bypass, session, blocking, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, durationMinutes: 5)

        var revokedApp: Data?
        bypass.onBypassRevoked = { revokedApp = $0 }

        let appToken = Data([1, 2, 3])
        try bypass.requestBypass(forApp: appToken)

        // Complete countdown
        for _ in 0..<60 {
            bypass.countdownTick()
        }
        #expect(bypass.isBypassActive == true)

        // Session completes
        bypass.handleSessionCompleted()

        #expect(bypass.bypassState == .idle)
        #expect(revokedApp == appToken)
    }

    // MARK: - Shared State Tests

    @Test("Bypass request sets shared state to active")
    func bypassRequestSetsSharedState() throws {
        let (bypass, session, blocking, _, sharedState) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        #expect(sharedState.isBypassActive() == false)

        try bypass.requestBypass(forApp: Data([1, 2, 3]))

        #expect(sharedState.isBypassActive() == true)
    }

    @Test("Cancel bypass clears shared state")
    func cancelBypassClearsSharedState() throws {
        let (bypass, session, blocking, _, sharedState) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try bypass.requestBypass(forApp: Data([1, 2, 3]))
        #expect(sharedState.isBypassActive() == true)

        bypass.cancelBypass()
        #expect(sharedState.isBypassActive() == false)
    }
}
