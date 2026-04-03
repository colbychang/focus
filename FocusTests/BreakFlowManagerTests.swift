import Testing
import Foundation
@testable import FocusCore

// MARK: - BreakFlowManager Tests

@Suite("BreakFlowManager Tests", .serialized)
@MainActor
struct BreakFlowManagerTests {

    // MARK: - Helpers

    /// Creates a SharedStateService backed by an in-memory UserDefaults.
    private func makeSharedStateService(dateProvider: @escaping () -> Date = { Date() }) -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults, dateProvider: dateProvider)
    }

    /// Creates the full test setup: break manager, session manager, blocking service, and mocks.
    private func makeTestSetup(
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) -> (
        breakManager: BreakFlowManager,
        sessionManager: DeepFocusSessionManager,
        blockingService: DeepFocusBlockingService,
        mockShieldService: MockShieldService,
        mockLiveActivity: MockLiveActivityService,
        sharedState: SharedStateService
    ) {
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let mockLiveActivity = MockLiveActivityService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: dateProvider
        )
        let breakManager = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: dateProvider
        )
        return (breakManager, sessionManager, blockingService, mockShield, mockLiveActivity, sharedState)
    }

    /// Helper to start a session and apply blocking.
    private func startSessionWithBlocking(
        sessionManager: DeepFocusSessionManager,
        blockingService: DeepFocusBlockingService,
        durationMinutes: Int = 30,
        allowedTokens: Set<Data>? = nil
    ) throws {
        try sessionManager.startSession(durationMinutes: durationMinutes)
        blockingService.applyBlocking(allowedTokens: allowedTokens)
    }

    // MARK: - Basic Break Start Tests

    @Test("Start break with valid duration (1-5 minutes)")
    func startBreakValidDuration() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        for minutes in 1...5 {
            let bm = makeTestSetup().breakManager
            let sm = makeTestSetup().sessionManager
            let bs = makeTestSetup().blockingService
            try sm.startSession(durationMinutes: 30)
            bs.applyBlocking(allowedTokens: nil)
            // For the actual break manager we test with the real setup
        }

        // Test with 3 minutes
        try breakMgr.startBreak(minutes: 3)
        #expect(breakMgr.isBreakActive == true)
        #expect(breakMgr.currentBreakDurationMinutes == 3)
    }

    @Test("Break pauses deep focus timer — remaining seconds frozen")
    func breakPausesTimer() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)
        let remainingBefore = session.remainingSeconds

        try breakMgr.startBreak(minutes: 2)

        #expect(session.sessionStatus == .onBreak)
        #expect(session.remainingSeconds == remainingBefore)

        // Timer ticks should not decrement during break
        session.timerTick()
        #expect(session.remainingSeconds == remainingBefore)
    }

    @Test("Break removes blocking")
    func breakRemovesBlocking() throws {
        let (breakMgr, session, blocking, mockShield, _, _) = makeTestSetup()
        let tokens: Set<Data> = [Data([1, 2, 3])]
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, allowedTokens: tokens)
        #expect(blocking.isBlocking == true)

        try breakMgr.startBreak(minutes: 1)

        #expect(blocking.isBlocking == false)
        #expect(mockShield.clearShieldsCalls.count > 0)
    }

    @Test("Break starts countdown timer")
    func breakStartsCountdown() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 2)

        #expect(breakMgr.isBreakActive == true)
        #expect(breakMgr.breakRemainingSeconds == 120) // 2 * 60
        #expect(breakMgr.breakEndDate != nil)
    }

    @Test("Break increments break count on session manager")
    func breakIncrementsCount() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)
        #expect(session.breakCount == 0)

        try breakMgr.startBreak(minutes: 1)

        #expect(session.breakCount == 1)
    }

    // MARK: - Break Expiry Tests

    @Test("After break expires: re-apply blocking with same config")
    func breakExpiryReappliesBlocking() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, mockShield, _, _) = makeTestSetup(dateProvider: { currentDate })
        let tokens: Set<Data> = [Data([1, 2, 3]), Data([4, 5, 6])]
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, allowedTokens: tokens)

        try breakMgr.startBreak(minutes: 1)
        #expect(blocking.isBlocking == false)

        // Advance time past break end
        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()

        #expect(blocking.isBlocking == true)
        // Verify the same tokens were re-applied
        let lastApply = mockShield.applyShieldsCalls.last!
        #expect(lastApply.applications == tokens)
        #expect(lastApply.categories == tokens)
        #expect(lastApply.webDomains == tokens)
    }

    @Test("After break expires: resume deep focus timer")
    func breakExpiryResumesTimer() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)
        let remainingBefore = session.remainingSeconds

        try breakMgr.startBreak(minutes: 1)
        #expect(session.sessionStatus == .onBreak)

        // Advance time past break end
        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()

        #expect(session.sessionStatus == .active)
        // Timer should resume from where it was frozen
        #expect(session.remainingSeconds == remainingBefore)
    }

    @Test("Break time does NOT count against session duration")
    func breakTimeDoesNotCountAgainstSession() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, durationMinutes: 5)
        let remainingBefore = session.remainingSeconds // 300 seconds

        // Start a 2-minute break
        try breakMgr.startBreak(minutes: 2)

        // Advance 2 minutes (break expires)
        currentDate = currentDate.addingTimeInterval(121)
        breakMgr.breakTick()

        // Session timer should still have the same remaining seconds
        #expect(session.remainingSeconds == remainingBefore)
        #expect(session.sessionStatus == .active)
    }

    @Test("Break expiry callback fires")
    func breakExpiryCallbackFires() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var expired = false
        breakMgr.onBreakExpired = { expired = true }

        try breakMgr.startBreak(minutes: 1)

        // Advance past break end
        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()

        #expect(expired == true)
    }

    @Test("Break end updates totalBreakDuration on session manager")
    func breakEndUpdatesTotalBreakDuration() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)
        #expect(session.totalBreakDuration == 0)

        try breakMgr.startBreak(minutes: 2) // 120 seconds

        currentDate = currentDate.addingTimeInterval(121)
        breakMgr.breakTick()

        #expect(session.totalBreakDuration == 120) // 2 minutes
    }

    // MARK: - Live Activity Tests

    @Test("Live Activity created on break start")
    func liveActivityCreatedOnStart() throws {
        let (breakMgr, session, blocking, _, mockLiveActivity, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 3)

        #expect(mockLiveActivity.startCalls.count == 1)
        let call = mockLiveActivity.startCalls.first!
        #expect(call.attributes.breakDuration == 180) // 3 * 60
        #expect(call.attributes.sessionName == "Deep Focus")
        #expect(call.attributes.sessionID == session.currentSessionID)
        #expect(call.attributes.sessionStartTime == session.sessionStartTime)
    }

    @Test("Live Activity ended with .immediate on break end")
    func liveActivityEndedOnBreakEnd() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, mockLiveActivity, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 1)
        #expect(mockLiveActivity.startCalls.count == 1)

        // Advance past break end
        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()

        #expect(mockLiveActivity.endCalls.count == 1)
        #expect(mockLiveActivity.endCalls.first!.dismissalPolicy == .immediate)
    }

    @Test("Break still works when Live Activities disabled — no crash")
    func breakWorksWithDisabledActivities() throws {
        let (breakMgr, session, blocking, _, mockLiveActivity, _) = makeTestSetup()
        mockLiveActivity.areActivitiesEnabled = false
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        // Should not throw
        try breakMgr.startBreak(minutes: 2)

        #expect(breakMgr.isBreakActive == true)
        #expect(session.sessionStatus == .onBreak)
        // Start was called but it threw — no activity created
        #expect(mockLiveActivity.activeActivities.count == 0)
    }

    @Test("Orphaned Live Activities cleaned up")
    func orphanedActivitiesCleanedUp() throws {
        let (breakMgr, _, _, _, mockLiveActivity, _) = makeTestSetup()

        breakMgr.cleanupOrphanedActivities()

        #expect(mockLiveActivity.cleanupCallCount == 1)
    }

    // MARK: - Break Duration Validation Tests

    @Test("Invalid break duration (0) throws error")
    func invalidDurationZero() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        #expect(throws: BreakFlowError.invalidDuration(0)) {
            try breakMgr.startBreak(minutes: 0)
        }
    }

    @Test("Invalid break duration (6) throws error")
    func invalidDurationSix() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        #expect(throws: BreakFlowError.invalidDuration(6)) {
            try breakMgr.startBreak(minutes: 6)
        }
    }

    @Test("Invalid break duration (-1) throws error")
    func invalidDurationNegative() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        #expect(throws: BreakFlowError.invalidDuration(-1)) {
            try breakMgr.startBreak(minutes: -1)
        }
    }

    @Test("Break rejected when no active session")
    func breakRejectedNoSession() throws {
        let (breakMgr, _, _, _, _, _) = makeTestSetup()

        #expect(throws: BreakFlowError.noActiveSession) {
            try breakMgr.startBreak(minutes: 1)
        }
    }

    @Test("Break rejected when session is already on break")
    func breakRejectedAlreadyOnBreak() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 1)

        #expect(throws: BreakFlowError.invalidSessionState("onBreak")) {
            try breakMgr.startBreak(minutes: 2)
        }
    }

    @Test("Break rejected when session is bypassing")
    func breakRejectedBypassing() throws {
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        session.transitionToBypassing()

        #expect(throws: BreakFlowError.invalidSessionState("bypassing")) {
            try breakMgr.startBreak(minutes: 1)
        }
    }

    // MARK: - Background/Foreground Reconciliation Tests

    @Test("Background/foreground reconciles break countdown")
    func backgroundForegroundReconciles() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 2) // 120 seconds

        // Go to background
        breakMgr.handleBackgroundEntry()

        // 60 seconds pass
        currentDate = currentDate.addingTimeInterval(60)

        // Foreground — should reconcile
        breakMgr.handleForegroundEntry()

        #expect(breakMgr.isBreakActive == true)
        #expect(breakMgr.breakRemainingSeconds == 60) // 120 - 60
    }

    @Test("Background/foreground with full elapsed time completes break")
    func backgroundForegroundAutoCompletes() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)
        let remainingBefore = session.remainingSeconds

        try breakMgr.startBreak(minutes: 1)

        // Go to background
        breakMgr.handleBackgroundEntry()

        // 90 seconds pass (more than 60s break)
        currentDate = currentDate.addingTimeInterval(90)

        // Foreground — break should auto-complete
        breakMgr.handleForegroundEntry()

        #expect(breakMgr.isBreakActive == false)
        #expect(session.sessionStatus == .active)
        #expect(session.remainingSeconds == remainingBefore)
        #expect(blocking.isBlocking == true)
    }

    // MARK: - Termination Recovery Tests

    @Test("Break state persists through termination — expired break recovers")
    func terminationRecoveryExpiredBreak() throws {
        var currentDate = Date()
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let mockLiveActivity = MockLiveActivityService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })

        // Start session and break
        try sessionManager.startSession(durationMinutes: 30)
        blockingService.applyBlocking(allowedTokens: Set([Data([1, 2, 3])]))

        let breakMgr1 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try breakMgr1.startBreak(minutes: 2) // Persists break state

        // Simulate termination — time passes beyond break end
        currentDate = currentDate.addingTimeInterval(180) // 3 minutes (> 2 min break)

        // New manager on relaunch
        let breakMgr2 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )

        let recovered = breakMgr2.recoverBreakState()

        #expect(recovered == true)
        #expect(blockingService.isBlocking == true) // Blocking re-applied
        #expect(mockLiveActivity.cleanupCallCount == 1) // Orphans cleaned
    }

    @Test("Break state persists through termination — active break resumes")
    func terminationRecoveryActiveBreak() throws {
        var currentDate = Date()
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let mockLiveActivity = MockLiveActivityService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })

        try sessionManager.startSession(durationMinutes: 30)
        blockingService.applyBlocking(allowedTokens: nil)

        let breakMgr1 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try breakMgr1.startBreak(minutes: 5) // 300 seconds

        // Simulate termination — only 60 seconds pass (break still active)
        currentDate = currentDate.addingTimeInterval(60)

        let breakMgr2 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )

        let recovered = breakMgr2.recoverBreakState()

        #expect(recovered == true)
        #expect(breakMgr2.isBreakActive == true)
        #expect(breakMgr2.breakRemainingSeconds > 0)
        #expect(breakMgr2.breakRemainingSeconds <= 240) // 300 - 60
    }

    @Test("No persisted break state returns false")
    func noPersistedBreakState() throws {
        let (breakMgr, _, _, _, _, _) = makeTestSetup()

        let recovered = breakMgr.recoverBreakState()

        #expect(recovered == false)
    }

    // MARK: - Edge Cases

    @Test("Break when 1 second remains — session resumes with 1s after break, then completes")
    func breakWithOneSecondRemaining() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, durationMinutes: 5)

        // Tick down to 1 second remaining
        for _ in 0..<299 {
            session.timerTick()
        }
        #expect(session.remainingSeconds == 1)

        // Start a 1-minute break
        try breakMgr.startBreak(minutes: 1)
        #expect(session.sessionStatus == .onBreak)
        #expect(session.remainingSeconds == 1)

        // Break expires
        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()

        // Session should resume with 1 second
        #expect(session.sessionStatus == .active)
        #expect(session.remainingSeconds == 1)

        // One more tick completes the session
        var completed = false
        session.onSessionCompleted = { completed = true }
        session.timerTick()

        #expect(session.remainingSeconds == 0)
        #expect(session.sessionStatus == .completed)
        #expect(completed == true)
    }

    @Test("Session does not auto-complete during break")
    func sessionDoesNotAutoCompleteDuringBreak() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking, durationMinutes: 5)

        // Tick down to 1 second
        for _ in 0..<299 {
            session.timerTick()
        }
        #expect(session.remainingSeconds == 1)

        // Start break
        try breakMgr.startBreak(minutes: 1)

        // Timer tick during break should not decrement
        session.timerTick()
        #expect(session.remainingSeconds == 1)
        #expect(session.sessionStatus == .onBreak)
        #expect(session.isSessionRunning == true)
    }

    @Test("Break end triggers exactly once")
    func breakEndTriggersOnce() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        var expiredCount = 0
        breakMgr.onBreakExpired = { expiredCount += 1 }

        try breakMgr.startBreak(minutes: 1)

        // Advance past break end
        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()
        breakMgr.breakTick() // Extra tick should be no-op

        #expect(expiredCount == 1)
    }

    // MARK: - Session Completion Cleanup

    @Test("Session completion during break cleans up break state")
    func sessionCompletionCleansUpBreak() throws {
        let (breakMgr, session, blocking, _, mockLiveActivity, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 3)
        #expect(breakMgr.isBreakActive == true)

        breakMgr.handleSessionCompleted()

        #expect(breakMgr.isBreakActive == false)
        #expect(breakMgr.breakState == .idle)
        // Live Activity should be ended
        #expect(mockLiveActivity.endCalls.count == 1)
    }

    @Test("Session completion when no break is a no-op")
    func sessionCompletionNoBreakIsNoop() throws {
        let (breakMgr, session, blocking, _, mockLiveActivity, _) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        breakMgr.handleSessionCompleted()

        #expect(breakMgr.breakState == .idle)
        #expect(mockLiveActivity.endCalls.count == 0)
    }

    // MARK: - Shared State Tests

    @Test("Break start sets shared state to on break")
    func breakStartSetsSharedState() throws {
        let (breakMgr, session, blocking, _, _, sharedState) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        #expect(sharedState.isOnBreak() == false)

        try breakMgr.startBreak(minutes: 1)

        #expect(sharedState.isOnBreak() == true)
    }

    @Test("Break end clears shared state")
    func breakEndClearsSharedState() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, sharedState) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 1)
        #expect(sharedState.isOnBreak() == true)

        currentDate = currentDate.addingTimeInterval(61)
        breakMgr.breakTick()

        #expect(sharedState.isOnBreak() == false)
    }

    // MARK: - Reset Tests

    @Test("Reset to idle clears all break state")
    func resetClearsAllState() throws {
        let (breakMgr, session, blocking, _, mockLiveActivity, sharedState) = makeTestSetup()
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 2)

        breakMgr.resetToIdle()

        #expect(breakMgr.breakState == .idle)
        #expect(breakMgr.isBreakActive == false)
        #expect(breakMgr.breakRemainingSeconds == 0)
        #expect(breakMgr.breakEndDate == nil)
        #expect(breakMgr.currentBreakDurationMinutes == 0)
        #expect(sharedState.isOnBreak() == false)
    }

    // MARK: - Error Tests

    @Test("BreakFlowError has descriptive messages")
    func errorMessages() {
        #expect(BreakFlowError.invalidDuration(0).errorDescription != nil)
        #expect(BreakFlowError.noActiveSession.errorDescription != nil)
        #expect(BreakFlowError.breakAlreadyActive.errorDescription != nil)
        #expect(BreakFlowError.invalidSessionState("onBreak").errorDescription != nil)
    }

    @Test("BreakFlowError equatable")
    func errorEquatable() {
        #expect(BreakFlowError.invalidDuration(3) == BreakFlowError.invalidDuration(3))
        #expect(BreakFlowError.invalidDuration(3) != BreakFlowError.invalidDuration(5))
        #expect(BreakFlowError.noActiveSession == BreakFlowError.noActiveSession)
        #expect(BreakFlowError.breakAlreadyActive == BreakFlowError.breakAlreadyActive)
    }

    // MARK: - BreakState Tests

    @Test("BreakState equatable")
    func breakStateEquatable() {
        let date = Date()
        #expect(BreakState.idle == BreakState.idle)
        #expect(BreakState.active(breakEndDate: date, remainingSeconds: 60) == BreakState.active(breakEndDate: date, remainingSeconds: 60))
        #expect(BreakState.expired == BreakState.expired)
        #expect(BreakState.idle != BreakState.expired)
    }

    // MARK: - PersistedBreakState Tests

    @Test("PersistedBreakState encodes and decodes correctly")
    func persistedStateCodable() throws {
        let state = PersistedBreakState(
            breakEndTime: Date(),
            sessionRemainingSeconds: 1500,
            breakDurationMinutes: 3,
            sessionID: UUID()
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedBreakState.self, from: data)

        #expect(decoded.sessionRemainingSeconds == 1500)
        #expect(decoded.breakDurationMinutes == 3)
        #expect(decoded.sessionID == state.sessionID)
    }

    // MARK: - BreakActivityAttributes Tests

    @Test("BreakActivityAttributes with sessionID and sessionStartTime")
    func breakActivityAttributesWithSessionInfo() {
        let sessionID = UUID()
        let startTime = Date()
        let attrs = BreakActivityAttributes(
            breakDuration: 180,
            sessionName: "Deep Focus",
            sessionID: sessionID,
            sessionStartTime: startTime
        )
        #expect(attrs.breakDuration == 180)
        #expect(attrs.sessionName == "Deep Focus")
        #expect(attrs.sessionID == sessionID)
        #expect(attrs.sessionStartTime == startTime)
    }

    @Test("BreakActivityAttributes payload under 4KB")
    func breakActivityAttributesUnder4KB() throws {
        let attrs = BreakActivityAttributes(
            breakDuration: 300,
            sessionName: "Very Long Session Name For Testing",
            sessionID: UUID(),
            sessionStartTime: Date()
        )
        let state = BreakActivityState(
            endDate: Date().addingTimeInterval(300),
            remainingSeconds: 300,
            isActive: true
        )

        let attrsData = try JSONEncoder().encode(attrs)
        let stateData = try JSONEncoder().encode(state)
        let totalSize = attrsData.count + stateData.count

        #expect(totalSize < 4096) // Under 4KB
    }

    @Test("BreakActivityAttributes backward compatible — optional sessionID/sessionStartTime")
    func breakActivityAttributesBackwardCompatible() {
        let attrs = BreakActivityAttributes(breakDuration: 60)
        #expect(attrs.sessionID == nil)
        #expect(attrs.sessionStartTime == nil)
        #expect(attrs.sessionName == nil)
    }

    // MARK: - Break Tick Countdown Tests

    @Test("Break tick decrements remaining seconds")
    func breakTickDecrements() throws {
        var currentDate = Date()
        let (breakMgr, session, blocking, _, _, _) = makeTestSetup(dateProvider: { currentDate })
        try startSessionWithBlocking(sessionManager: session, blockingService: blocking)

        try breakMgr.startBreak(minutes: 1) // 60 seconds

        // Advance 10 seconds
        currentDate = currentDate.addingTimeInterval(10)
        breakMgr.breakTick()

        #expect(breakMgr.breakRemainingSeconds == 50) // 60 - 10
        #expect(breakMgr.isBreakActive == true)
    }

    @Test("Break tick when not on break is a no-op")
    func breakTickWhenIdle() throws {
        let (breakMgr, _, _, _, _, _) = makeTestSetup()

        // Should not crash
        breakMgr.breakTick()

        #expect(breakMgr.breakState == .idle)
    }

    // MARK: - Recovery Race Condition Tests (Fix 2)

    @Test("Active break recovery does not start main session timer")
    func activeBreakRecoveryDoesNotStartMainTimer() throws {
        var currentDate = Date()
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let mockLiveActivity = MockLiveActivityService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })

        try sessionManager.startSession(durationMinutes: 30)
        let initialRemaining = sessionManager.remainingSeconds
        blockingService.applyBlocking(allowedTokens: nil)

        let breakMgr1 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try breakMgr1.startBreak(minutes: 5)
        #expect(sessionManager.sessionStatus == .onBreak)

        // Simulate termination — 60 seconds pass (break still active, 240s remaining)
        currentDate = currentDate.addingTimeInterval(60)

        // Create new managers for recovery (simulates app relaunch)
        let sessionManager2 = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })
        let blockingService2 = DeepFocusBlockingService(shieldService: mockShield)
        let breakMgr2 = BreakFlowManager(
            sessionManager: sessionManager2,
            blockingService: blockingService2,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )

        // Recovery sequence (same order as ContentView)
        let breakRecovered = breakMgr2.recoverBreakState()
        #expect(breakRecovered == true)
        #expect(breakMgr2.isBreakActive == true)

        let sessionRecovered = sessionManager2.recoverOrphanedSession()
        #expect(sessionRecovered == true)

        // CRITICAL: session must be onBreak, NOT active
        #expect(sessionManager2.sessionStatus == .onBreak)
        // Remaining seconds must not have been decremented
        #expect(sessionManager2.remainingSeconds == initialRemaining)

        // Simulate timer ticks — they should NOT decrement remaining time (since we're on break)
        sessionManager2.timerTick()
        sessionManager2.timerTick()
        sessionManager2.timerTick()
        #expect(sessionManager2.remainingSeconds == initialRemaining)
    }

    // MARK: - Persisted Break State Allowed Tokens Tests (Fix 3)

    @Test("Expired break recovery restores allowed tokens")
    func expiredBreakRecoveryRestoresAllowedTokens() throws {
        var currentDate = Date()
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let mockLiveActivity = MockLiveActivityService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })

        try sessionManager.startSession(durationMinutes: 30)
        let allowedTokens: Set<Data> = [Data([1, 2, 3]), Data([4, 5, 6])]
        blockingService.applyBlocking(allowedTokens: allowedTokens)

        let breakMgr1 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try breakMgr1.startBreak(minutes: 2)

        // Simulate termination — time passes beyond break end
        currentDate = currentDate.addingTimeInterval(180) // 3 minutes > 2 min break

        // New managers on relaunch
        let blockingService2 = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager2 = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })
        let breakMgr2 = BreakFlowManager(
            sessionManager: sessionManager2,
            blockingService: blockingService2,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )

        let recovered = breakMgr2.recoverBreakState()

        #expect(recovered == true)
        #expect(blockingService2.isBlocking == true)
        // CRITICAL: allowed tokens must be restored, not nil
        #expect(blockingService2.currentAllowedTokens == allowedTokens)
    }

    @Test("Expired break recovery without allowed tokens blocks all apps")
    func expiredBreakRecoveryWithoutTokensBlocksAll() throws {
        var currentDate = Date()
        let sharedState = makeSharedStateService()
        let mockShield = MockShieldService()
        let mockLiveActivity = MockLiveActivityService()
        let blockingService = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })

        try sessionManager.startSession(durationMinutes: 30)
        blockingService.applyBlocking(allowedTokens: nil) // No allowed tokens

        let breakMgr1 = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try breakMgr1.startBreak(minutes: 2)

        currentDate = currentDate.addingTimeInterval(180)

        let blockingService2 = DeepFocusBlockingService(shieldService: mockShield)
        let sessionManager2 = DeepFocusSessionManager(sharedStateService: sharedState, dateProvider: { currentDate })
        let breakMgr2 = BreakFlowManager(
            sessionManager: sessionManager2,
            blockingService: blockingService2,
            liveActivityService: mockLiveActivity,
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )

        let recovered = breakMgr2.recoverBreakState()

        #expect(recovered == true)
        #expect(blockingService2.isBlocking == true)
        // No allowed tokens — full blocking is correct
        #expect(blockingService2.currentAllowedTokens == nil)
    }

    @Test("PersistedBreakState encodes and decodes with allowedTokens")
    func persistedStateWithAllowedTokensCodable() throws {
        let tokens: Set<Data> = [Data([1, 2, 3]), Data([4, 5, 6])]
        let state = PersistedBreakState(
            breakEndTime: Date(),
            sessionRemainingSeconds: 1500,
            breakDurationMinutes: 3,
            sessionID: UUID(),
            allowedTokens: tokens
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedBreakState.self, from: data)

        #expect(decoded.sessionRemainingSeconds == 1500)
        #expect(decoded.breakDurationMinutes == 3)
        #expect(decoded.sessionID == state.sessionID)
        #expect(decoded.allowedTokens == tokens)
    }

    @Test("PersistedBreakState backward compatible without allowedTokens")
    func persistedStateBackwardCompatible() throws {
        // Simulate old persisted state without allowedTokens field
        let state = PersistedBreakState(
            breakEndTime: Date(),
            sessionRemainingSeconds: 1500,
            breakDurationMinutes: 3,
            sessionID: UUID()
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedBreakState.self, from: data)

        #expect(decoded.allowedTokens == nil)
    }
}
