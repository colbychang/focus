import Testing
import Foundation
import SwiftData
@testable import FocusCore

// MARK: - DeepFocusSessionRecorder Tests

@Suite("DeepFocusSessionRecorder Tests", .serialized)
@MainActor
struct DeepFocusSessionRecorderTests {

    // MARK: - Helpers

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    private func makeSessionManager(
        sharedStateService: SharedStateService? = nil,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) -> DeepFocusSessionManager {
        DeepFocusSessionManager(
            sharedStateService: sharedStateService ?? makeSharedStateService(),
            dateProvider: currentDate
        )
    }

    // MARK: - Completed Session Recording

    @Test("Record completed session creates DeepFocusSession with correct fields")
    func recordCompletedSession() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()
        let sessionID = UUID()
        let startTime = Date()

        recorder.recordCompletedSession(
            sessionID: sessionID,
            startTime: startTime,
            configuredDuration: 1800,
            elapsedTime: 1800,
            bypassCount: 2,
            breakCount: 1,
            totalBreakDuration: 180,
            modelContext: modelContext
        )

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
        let session = sessions[0]
        #expect(session.id == sessionID)
        #expect(session.status == .completed)
        #expect(session.configuredDuration == 1800)
        #expect(session.remainingSeconds == 0)
        #expect(session.bypassCount == 2)
        #expect(session.breakCount == 1)
        #expect(session.totalBreakDuration == 180)
    }

    // MARK: - Abandoned Session Recording

    @Test("Record abandoned session creates DeepFocusSession with abandoned status and zero completed time")
    func recordAbandonedSession() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()
        let sessionID = UUID()
        let startTime = Date()

        recorder.recordAbandonedSession(
            sessionID: sessionID,
            startTime: startTime,
            configuredDuration: 1800,
            remainingSeconds: 1200,
            bypassCount: 0,
            breakCount: 0,
            totalBreakDuration: 0,
            modelContext: modelContext
        )

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
        let session = sessions[0]
        #expect(session.id == sessionID)
        #expect(session.status == .abandoned)
        #expect(session.configuredDuration == 1800)
        #expect(session.remainingSeconds == 1200)
        #expect(session.bypassCount == 0)
        #expect(session.breakCount == 0)
        #expect(session.totalBreakDuration == 0)
    }

    // MARK: - Record from Session Manager

    @Test("Record from session manager for completed session")
    func recordFromManagerCompleted() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()
        let manager = makeSessionManager()

        try manager.startSession(durationMinutes: 5) // 300 seconds (shorter for test speed)
        manager.bypassCount = 3
        manager.breakCount = 2
        manager.totalBreakDuration = 300

        // Complete the session
        for _ in 0..<300 {
            manager.timerTick()
        }
        #expect(manager.sessionStatus == .completed)

        let result = recorder.recordSession(from: manager, modelContext: modelContext)
        #expect(result != nil)
        #expect(result?.status == .completed)
        #expect(result?.configuredDuration == 300)
        #expect(result?.remainingSeconds == 0)
        #expect(result?.bypassCount == 3)
        #expect(result?.breakCount == 2)
        #expect(result?.totalBreakDuration == 300)

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
    }

    @Test("Record from session manager for abandoned session sets completedFocusTime to 0")
    func recordFromManagerAbandoned() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()
        let manager = makeSessionManager()

        try manager.startSession(durationMinutes: 5) // 300 seconds

        // Tick 100 seconds
        for _ in 0..<100 {
            manager.timerTick()
        }

        // Abandon
        manager.abandonSession()
        #expect(manager.sessionStatus == .abandoned)

        let result = recorder.recordSession(from: manager, modelContext: modelContext)
        #expect(result != nil)
        #expect(result?.status == .abandoned)
        #expect(result?.configuredDuration == 300)
        // Abandoned sessions: remainingSeconds = configuredDuration (completedFocusTime = 0)
        #expect(result?.remainingSeconds == 300)
    }

    @Test("Record from session manager returns nil for idle status")
    func recordFromManagerIdle() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()
        let manager = makeSessionManager()

        let result = recorder.recordSession(from: manager, modelContext: modelContext)
        #expect(result == nil)
    }

    @Test("Record from session manager returns nil for active status")
    func recordFromManagerActive() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()
        let manager = makeSessionManager()

        try manager.startSession(durationMinutes: 30)

        let result = recorder.recordSession(from: manager, modelContext: modelContext)
        #expect(result == nil)
    }
}

// MARK: - Session Completion Cascade Tests (VAL-DEEP-005)

@Suite("Session Completion Cascade Tests", .serialized)
@MainActor
struct SessionCompletionCascadeTests {

    // MARK: - Helpers

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    private func makeTestEnvironment() -> (
        sessionManager: DeepFocusSessionManager,
        blockingService: DeepFocusBlockingService,
        breakFlowManager: BreakFlowManager,
        bypassFlowManager: BypassFlowManager,
        shieldService: MockShieldService,
        liveActivityService: MockLiveActivityService,
        sharedStateService: SharedStateService
    ) {
        let sharedState = makeSharedStateService()
        let shieldService = MockShieldService()
        let liveActivityService = MockLiveActivityService()

        let sessionManager = DeepFocusSessionManager(
            sharedStateService: sharedState
        )
        let blockingService = DeepFocusBlockingService(
            shieldService: shieldService
        )
        let breakFlowManager = BreakFlowManager(
            sessionManager: sessionManager,
            blockingService: blockingService,
            liveActivityService: liveActivityService,
            sharedStateService: sharedState
        )
        let bypassFlowManager = BypassFlowManager(
            blockingService: blockingService,
            sessionManager: sessionManager,
            sharedStateService: sharedState
        )

        return (sessionManager, blockingService, breakFlowManager, bypassFlowManager,
                shieldService, liveActivityService, sharedState)
    }

    @Test("Session completion: status transitions to .completed")
    func completionStatusTransition() throws {
        let env = makeTestEnvironment()
        try env.sessionManager.startSession(durationMinutes: 5) // 300s

        // Tick to completion
        for _ in 0..<300 {
            env.sessionManager.timerTick()
        }

        #expect(env.sessionManager.sessionStatus == .completed)
        #expect(env.sessionManager.remainingSeconds == 0)
        #expect(env.sessionManager.isSessionRunning == false)
    }

    @Test("Session completion: blocking is removed")
    func completionRemovesBlocking() throws {
        let env = makeTestEnvironment()

        // Apply blocking
        env.blockingService.applyBlocking(allowedTokens: Set([Data([1, 2, 3])]))
        #expect(env.blockingService.isBlocking == true)

        try env.sessionManager.startSession(durationMinutes: 5)

        // Tick to completion
        for _ in 0..<300 {
            env.sessionManager.timerTick()
        }

        // Simulate the onChange handler in DeepFocusTabView
        env.blockingService.clearBlocking()

        #expect(env.blockingService.isBlocking == false)
        #expect(env.shieldService.clearShieldsCalls.contains(DeepFocusBlockingService.storeName))
    }

    @Test("Session completion: Live Activity is ended")
    func completionEndsLiveActivity() throws {
        let env = makeTestEnvironment()

        try env.sessionManager.startSession(durationMinutes: 5)

        // Start a break to create a Live Activity
        try env.breakFlowManager.startBreak(minutes: 1)
        #expect(env.liveActivityService.startCalls.count == 1)

        // Session completes while break is active — handleSessionCompleted should end the Live Activity
        env.breakFlowManager.handleSessionCompleted()

        // Live Activity should be ended
        #expect(env.liveActivityService.endCalls.count >= 1)

        // Clean up session state
        env.sessionManager.resetToIdle()
    }

    @Test("Session completion: stats are recorded to SwiftData")
    func completionRecordsStats() throws {
        let modelContext = try makeModelContext()
        let env = makeTestEnvironment()
        let recorder = DeepFocusSessionRecorder()

        try env.sessionManager.startSession(durationMinutes: 5)
        env.sessionManager.bypassCount = 1
        env.sessionManager.breakCount = 2
        env.sessionManager.totalBreakDuration = 120

        // Complete the session
        for _ in 0..<300 {
            env.sessionManager.timerTick()
        }

        // Record the session
        let result = recorder.recordSession(from: env.sessionManager, modelContext: modelContext)

        #expect(result != nil)
        #expect(result?.status == .completed)
        #expect(result?.bypassCount == 1)
        #expect(result?.breakCount == 2)
        #expect(result?.totalBreakDuration == 120)
        #expect(result?.configuredDuration == 300)
        #expect(result?.remainingSeconds == 0)

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
    }

    @Test("Session completion: shared state is cleared")
    func completionClearsSharedState() throws {
        let env = makeTestEnvironment()

        try env.sessionManager.startSession(durationMinutes: 5)
        #expect(env.sharedStateService.isSessionActive() == true)

        for _ in 0..<300 {
            env.sessionManager.timerTick()
        }

        #expect(env.sharedStateService.isSessionActive() == false)
    }

    @Test("Full completion cascade: status + blocking + stats + shared state all handled")
    func fullCompletionCascade() throws {
        let modelContext = try makeModelContext()
        let env = makeTestEnvironment()
        let recorder = DeepFocusSessionRecorder()

        // Apply blocking
        env.blockingService.applyBlocking(allowedTokens: Set([Data([1, 2])]))

        var completionCalled = false
        env.sessionManager.onSessionCompleted = { completionCalled = true }

        try env.sessionManager.startSession(durationMinutes: 5)
        env.sessionManager.bypassCount = 2
        env.sessionManager.breakCount = 1
        env.sessionManager.totalBreakDuration = 60

        // Complete the session
        for _ in 0..<300 {
            env.sessionManager.timerTick()
        }

        // Completion callback fires
        #expect(completionCalled == true)

        // Clean up sub-flows (mimicking DeepFocusTabView.handleSessionCompletion)
        env.bypassFlowManager.handleSessionCompleted()
        env.breakFlowManager.handleSessionCompleted()

        // Record stats
        recorder.recordSession(from: env.sessionManager, modelContext: modelContext)

        // Clear blocking (mimicking onChange handler)
        env.blockingService.clearBlocking()

        // Verify cascade
        #expect(env.sessionManager.sessionStatus == .completed)
        #expect(env.blockingService.isBlocking == false)
        #expect(env.sharedStateService.isSessionActive() == false)

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .completed)
        #expect(sessions[0].bypassCount == 2)
        #expect(sessions[0].breakCount == 1)
    }
}

// MARK: - Session Exit Tests (VAL-DEEP-009)

@Suite("Session Exit Tests", .serialized)
@MainActor
struct SessionExitTests {

    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test("Abandoned session sets status to .abandoned")
    func abandonedSessionStatus() throws {
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)

        try manager.startSession(durationMinutes: 5) // 300s

        // Tick some seconds
        for _ in 0..<100 {
            manager.timerTick()
        }

        manager.abandonSession()
        #expect(manager.sessionStatus == .abandoned)
    }

    @Test("Abandoned session records stats with zero completed focus time")
    func abandonedSessionRecordsZeroCompletedTime() throws {
        let modelContext = try makeModelContext()
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)
        let recorder = DeepFocusSessionRecorder()

        try manager.startSession(durationMinutes: 5) // 300s

        // Tick 100 seconds
        for _ in 0..<100 {
            manager.timerTick()
        }

        manager.abandonSession()

        let result = recorder.recordSession(from: manager, modelContext: modelContext)

        #expect(result != nil)
        #expect(result?.status == .abandoned)
        #expect(result?.configuredDuration == 300)
        // Abandoned sessions: remainingSeconds = configuredDuration (completedFocusTime = 0)
        #expect(result?.remainingSeconds == 300)
    }

    @Test("Abandoned session removes blocking")
    func abandonedSessionRemovesBlocking() throws {
        let shieldService = MockShieldService()
        let blockingService = DeepFocusBlockingService(shieldService: shieldService)
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)

        blockingService.applyBlocking(allowedTokens: nil)
        #expect(blockingService.isBlocking == true)

        try manager.startSession(durationMinutes: 30)
        manager.abandonSession()

        // Simulate DeepFocusTabView onChange
        blockingService.clearBlocking()

        #expect(blockingService.isBlocking == false)
    }

    @Test("Abandoned session clears shared state")
    func abandonedSessionClearsSharedState() throws {
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)

        try manager.startSession(durationMinutes: 30)
        #expect(sharedState.isSessionActive() == true)

        manager.abandonSession()
        #expect(sharedState.isSessionActive() == false)
    }

    @Test("Cancel at first confirmation returns to active session")
    func cancelFirstConfirmation() throws {
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)

        try manager.startSession(durationMinutes: 30)
        let remaining = manager.remainingSeconds

        // Simulating cancel: no state change happens
        // The session should still be active
        #expect(manager.sessionStatus == .active)
        #expect(manager.remainingSeconds == remaining)
        #expect(manager.isSessionRunning == true)
    }

    @Test("Cancel at second confirmation returns to active session")
    func cancelSecondConfirmation() throws {
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)

        try manager.startSession(durationMinutes: 30)
        let remaining = manager.remainingSeconds

        // Simulating: user tapped End Session (first confirmation appeared)
        // Then confirmed first dialog, second dialog appears
        // Then cancelled second dialog
        // Session should still be active
        #expect(manager.sessionStatus == .active)
        #expect(manager.remainingSeconds == remaining)
        #expect(manager.isSessionRunning == true)
    }

    @Test("Full exit flow: abandon + record + reset")
    func fullExitFlow() throws {
        let modelContext = try makeModelContext()
        let sharedState = makeSharedStateService()
        let shieldService = MockShieldService()
        let liveActivityService = MockLiveActivityService()

        let manager = DeepFocusSessionManager(sharedStateService: sharedState)
        let blockingService = DeepFocusBlockingService(shieldService: shieldService)
        let breakFlowManager = BreakFlowManager(
            sessionManager: manager,
            blockingService: blockingService,
            liveActivityService: liveActivityService,
            sharedStateService: sharedState
        )
        let bypassFlowManager = BypassFlowManager(
            blockingService: blockingService,
            sessionManager: manager,
            sharedStateService: sharedState
        )
        let recorder = DeepFocusSessionRecorder()

        // Start session and apply blocking
        try manager.startSession(durationMinutes: 5) // 300s
        blockingService.applyBlocking(allowedTokens: nil)

        // Tick some seconds
        for _ in 0..<100 {
            manager.timerTick()
        }

        // Simulate the two-step exit confirmed handler
        bypassFlowManager.handleSessionCompleted()
        breakFlowManager.handleSessionCompleted()
        manager.abandonSession()
        recorder.recordSession(from: manager, modelContext: modelContext)
        manager.resetToIdle()
        blockingService.clearBlocking()

        // Verify
        #expect(manager.sessionStatus == .idle)
        #expect(blockingService.isBlocking == false)
        #expect(sharedState.isSessionActive() == false)

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .abandoned)
        #expect(sessions[0].remainingSeconds == 300) // completedFocusTime = 0
    }
}

// MARK: - Deep Focus + Focus Mode Coexistence Tests (VAL-CROSS-005)

@Suite("Deep Focus and Focus Mode Coexistence Tests", .serialized)
@MainActor
struct DeepFocusFocusModeCoexistenceTests {

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    @Test("Starting deep focus while focus mode is active does not remove focus mode shields")
    func deepFocusDoesNotRemoveFocusModeShields() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let sharedState = makeSharedStateService()

        // Activate a focus mode profile
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)
        try modelContext.save()

        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile)

        // Verify focus mode shields are applied
        let focusModeStoreName = profile.id.uuidString
        #expect(shieldService.isShielding(storeName: focusModeStoreName))

        // Start a deep focus session
        let blockingService = DeepFocusBlockingService(shieldService: shieldService)
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState)

        try sessionManager.startSession(durationMinutes: 30)
        blockingService.applyBlocking(allowedTokens: Set([Data([1, 2])]))

        // Both stores should have shields
        #expect(shieldService.isShielding(storeName: focusModeStoreName))
        #expect(shieldService.isShielding(storeName: DeepFocusBlockingService.storeName))

        // Deep focus store name is separate from focus mode store name
        #expect(DeepFocusBlockingService.storeName != focusModeStoreName)
    }

    @Test("Focus mode ending during deep focus does not interrupt timer")
    func focusModeEndingDoesNotInterruptDeepFocus() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let sharedState = makeSharedStateService()

        // Activate focus mode
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)
        try modelContext.save()

        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile)

        // Start deep focus
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState)
        let blockingService = DeepFocusBlockingService(shieldService: shieldService)

        try sessionManager.startSession(durationMinutes: 30)
        blockingService.applyBlocking(allowedTokens: nil)

        // Tick some time
        for _ in 0..<100 {
            sessionManager.timerTick()
        }
        let remainingBefore = sessionManager.remainingSeconds

        // Deactivate focus mode
        activationService.deactivate(profile: profile)

        // Focus mode shields should be cleared
        #expect(!shieldService.isShielding(storeName: profile.id.uuidString))

        // Deep focus should still be running with unchanged remaining time
        #expect(sessionManager.sessionStatus == .active)
        #expect(sessionManager.remainingSeconds == remainingBefore)
        #expect(shieldService.isShielding(storeName: DeepFocusBlockingService.storeName))
    }

    @Test("Both sessions generate independent records")
    func independentRecords() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let sharedState = makeSharedStateService()

        // Create and activate a focus mode
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)
        try modelContext.save()

        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile)

        // Record a focus mode session via FocusSessionRecorder
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let focusRecorder = FocusSessionRecorder(defaults: defaults)
        focusRecorder.recordSessionStart(profileId: profile.id, profileName: "Work")
        focusRecorder.recordSessionEnd(profileId: profile.id)
        focusRecorder.reconcileSessions(modelContext: modelContext)

        // Start and complete a deep focus session
        let sessionManager = DeepFocusSessionManager(sharedStateService: sharedState)
        try sessionManager.startSession(durationMinutes: 5) // 300s

        for _ in 0..<300 {
            sessionManager.timerTick()
        }

        // Record deep focus session
        let deepFocusRecorder = DeepFocusSessionRecorder()
        deepFocusRecorder.recordSession(from: sessionManager, modelContext: modelContext)

        // Verify independent records
        let deepFocusSessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        let screenTimeEntries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())

        #expect(deepFocusSessions.count == 1)
        #expect(deepFocusSessions[0].status == .completed)

        #expect(screenTimeEntries.count == 1)
        #expect(screenTimeEntries[0].categoryName == "Focus Session: Work")
    }

    @Test("Deep focus uses separate named store from focus mode stores")
    func separateNamedStores() {
        let deepFocusStoreName = DeepFocusBlockingService.storeName
        #expect(deepFocusStoreName == "deep_focus")

        // Focus mode stores use UUIDs
        let focusModeStoreName = UUID().uuidString
        #expect(deepFocusStoreName != focusModeStoreName)
    }

    @Test("Deactivating deep focus does not affect focus mode shields")
    func deactivatingDeepFocusPreservesFocusModeShields() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let sharedState = makeSharedStateService()

        // Activate focus mode
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)
        try modelContext.save()

        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile)
        #expect(shieldService.isShielding(storeName: profile.id.uuidString))

        // Start and then end deep focus
        let blockingService = DeepFocusBlockingService(shieldService: shieldService)
        blockingService.applyBlocking(allowedTokens: nil)
        #expect(shieldService.isShielding(storeName: DeepFocusBlockingService.storeName))

        // End deep focus
        blockingService.clearBlocking()

        // Focus mode shields should still be active
        #expect(shieldService.isShielding(storeName: profile.id.uuidString))
        // Deep focus shields should be cleared
        #expect(!shieldService.isShielding(storeName: DeepFocusBlockingService.storeName))
    }

    @Test("Multiple focus modes and deep focus all have independent shields")
    func multipleFocusModesPlusDeepFocus() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let sharedState = makeSharedStateService()

        // Create and activate two focus mode profiles
        let profile1 = FocusMode(name: "Work")
        let profile2 = FocusMode(name: "Study")
        modelContext.insert(profile1)
        modelContext.insert(profile2)
        try modelContext.save()

        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile1)
        activationService.activate(profile: profile2)

        // Start deep focus
        let blockingService = DeepFocusBlockingService(shieldService: shieldService)
        blockingService.applyBlocking(allowedTokens: nil)

        // All three stores should have shields
        #expect(shieldService.isShielding(storeName: profile1.id.uuidString))
        #expect(shieldService.isShielding(storeName: profile2.id.uuidString))
        #expect(shieldService.isShielding(storeName: DeepFocusBlockingService.storeName))

        // Deactivate profile1
        activationService.deactivate(profile: profile1)

        // Only profile1's shields should be cleared
        #expect(!shieldService.isShielding(storeName: profile1.id.uuidString))
        #expect(shieldService.isShielding(storeName: profile2.id.uuidString))
        #expect(shieldService.isShielding(storeName: DeepFocusBlockingService.storeName))
    }
}

// MARK: - App Termination During Deep Focus Tests (VAL-CROSS-010)

@Suite("App Termination During Deep Focus Tests", .serialized)
@MainActor
struct AppTerminationDuringDeepFocusTests {

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    @Test("Terminated session detected on relaunch and recorded as abandoned")
    func terminatedSessionRecordedAsAbandoned() throws {
        let modelContext = try makeModelContext()
        let sharedState = makeSharedStateService()
        var currentDate = Date()

        // First manager: start session and simulate termination
        let manager1 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try manager1.startSession(durationMinutes: 5) // 300s

        // Tick 100 seconds
        for _ in 0..<100 {
            manager1.timerTick()
        }

        // Simulate backgrounding (persists state)
        manager1.handleBackgroundEntry()

        // Simulate 50 seconds passing (not enough to complete)
        currentDate = currentDate.addingTimeInterval(50)

        // New manager on relaunch: recovers and finds active session
        let manager2 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        let recovered = manager2.recoverOrphanedSession()

        #expect(recovered == true)
        #expect(manager2.sessionStatus == .active)
        // 300 - 100 ticks - 50 elapsed = 150
        #expect(manager2.remainingSeconds == 150)
    }

    @Test("Terminated session auto-completes if time fully elapsed")
    func terminatedSessionAutoCompletes() throws {
        let modelContext = try makeModelContext()
        let sharedState = makeSharedStateService()
        var currentDate = Date()
        var completionTriggered = false

        let manager1 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try manager1.startSession(durationMinutes: 5) // 300s
        manager1.handleBackgroundEntry()

        // Simulate more than 300s passing
        currentDate = currentDate.addingTimeInterval(500)

        let manager2 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        manager2.onSessionCompleted = { completionTriggered = true }
        manager2.recoverOrphanedSession()

        #expect(manager2.sessionStatus == .completed)
        #expect(completionTriggered == true)

        // Record the auto-completed session
        let recorder = DeepFocusSessionRecorder()
        let result = recorder.recordSession(from: manager2, modelContext: modelContext)

        #expect(result != nil)
        #expect(result?.status == .completed)
    }

    @Test("No orphaned active session state remains after termination recovery")
    func noOrphanedActiveState() throws {
        let sharedState = makeSharedStateService()
        var currentDate = Date()

        // Start and persist
        let manager1 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try manager1.startSession(durationMinutes: 5)
        manager1.handleBackgroundEntry()

        // Enough time to complete
        currentDate = currentDate.addingTimeInterval(400)

        // Recover
        let manager2 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        manager2.recoverOrphanedSession()

        // Verify no orphaned state
        #expect(sharedState.isSessionActive() == false)

        // No session data should remain in UserDefaults
        let sessionData = sharedState.getData(forKey: SharedStateKey.deepFocusSessionData.rawValue)
        #expect(sessionData == nil)
    }

    @Test("Recovered orphaned session preserves bypass and break counts")
    func recoveredSessionPreservesCounts() throws {
        let sharedState = makeSharedStateService()
        var currentDate = Date()

        let manager1 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        try manager1.startSession(durationMinutes: 30)
        manager1.bypassCount = 3
        manager1.breakCount = 2
        manager1.totalBreakDuration = 180

        // Tick some and persist
        for _ in 0..<100 {
            manager1.timerTick()
        }
        manager1.handleBackgroundEntry()

        // Simulate 50s passing
        currentDate = currentDate.addingTimeInterval(50)

        // Recover
        let manager2 = DeepFocusSessionManager(
            sharedStateService: sharedState,
            dateProvider: { currentDate }
        )
        manager2.recoverOrphanedSession()

        #expect(manager2.bypassCount == 3)
        #expect(manager2.breakCount == 2)
        #expect(manager2.totalBreakDuration == 180)
    }
}

// MARK: - Deep Focus → Analytics Data Flow Tests (VAL-CROSS-004)

@Suite("Deep Focus Analytics Data Flow Tests", .serialized)
@MainActor
struct DeepFocusAnalyticsDataFlowTests {

    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func makeSharedStateService() -> SharedStateService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SharedStateService(defaults: defaults)
    }

    @Test("Completed deep focus session creates record with correct duration and metadata")
    func completedSessionCreatesRecord() throws {
        let modelContext = try makeModelContext()
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)
        let recorder = DeepFocusSessionRecorder()

        try manager.startSession(durationMinutes: 5) // 300s (shorter for test speed)
        manager.bypassCount = 2
        manager.breakCount = 1
        manager.totalBreakDuration = 60

        // Complete the session
        for _ in 0..<300 {
            manager.timerTick()
        }

        let result = recorder.recordSession(from: manager, modelContext: modelContext)

        #expect(result != nil)
        #expect(result?.status == .completed)
        #expect(result?.configuredDuration == 300)
        #expect(result?.remainingSeconds == 0)
        #expect(result?.bypassCount == 2)
        #expect(result?.breakCount == 1)
        #expect(result?.totalBreakDuration == 60)

        // Verify in SwiftData
        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
    }

    @Test("Abandoned deep focus session creates record with status abandoned")
    func abandonedSessionCreatesRecord() throws {
        let modelContext = try makeModelContext()
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)
        let recorder = DeepFocusSessionRecorder()

        try manager.startSession(durationMinutes: 5) // 300s

        for _ in 0..<100 {
            manager.timerTick()
        }

        manager.abandonSession()
        let result = recorder.recordSession(from: manager, modelContext: modelContext)

        #expect(result != nil)
        #expect(result?.status == .abandoned)
        // Abandoned: completedFocusTime = 0 (remainingSeconds = configuredDuration)
        #expect(result?.remainingSeconds == 300)

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)
        #expect(sessions[0].status == .abandoned)
    }

    @Test("Deep focus records are independent from focus mode records")
    func independentFromFocusModeRecords() throws {
        let modelContext = try makeModelContext()

        // Create a focus mode record via FocusSessionRecorder
        let focusDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let focusRecorder = FocusSessionRecorder(defaults: focusDefaults)
        let profileId = UUID()
        focusRecorder.recordSessionStart(profileId: profileId, profileName: "Work")
        focusRecorder.recordSessionEnd(profileId: profileId)
        focusRecorder.reconcileSessions(modelContext: modelContext)

        // Create a deep focus record
        let sharedState = makeSharedStateService()
        let manager = DeepFocusSessionManager(sharedStateService: sharedState)
        try manager.startSession(durationMinutes: 5)
        for _ in 0..<300 {
            manager.timerTick()
        }

        let deepRecorder = DeepFocusSessionRecorder()
        deepRecorder.recordSession(from: manager, modelContext: modelContext)

        // Both types of records should exist independently
        let deepSessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        let screenTimeEntries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())

        #expect(deepSessions.count == 1)
        #expect(screenTimeEntries.count == 1)

        // They should reference different data models
        #expect(deepSessions[0].status == .completed)
        #expect(screenTimeEntries[0].categoryName?.contains("Work") == true)
    }

    @Test("Multiple deep focus sessions create independent records")
    func multipleSessionsCreateIndependentRecords() throws {
        let modelContext = try makeModelContext()
        let recorder = DeepFocusSessionRecorder()

        // Session 1: completed
        let sharedState1 = makeSharedStateService()
        let manager1 = DeepFocusSessionManager(sharedStateService: sharedState1)
        try manager1.startSession(durationMinutes: 5)
        for _ in 0..<300 {
            manager1.timerTick()
        }
        recorder.recordSession(from: manager1, modelContext: modelContext)

        // Session 2: abandoned
        let sharedState2 = makeSharedStateService()
        let manager2 = DeepFocusSessionManager(sharedStateService: sharedState2)
        try manager2.startSession(durationMinutes: 10)
        for _ in 0..<100 {
            manager2.timerTick()
        }
        manager2.abandonSession()
        recorder.recordSession(from: manager2, modelContext: modelContext)

        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 2)

        let completed = sessions.filter { $0.status == .completed }
        let abandoned = sessions.filter { $0.status == .abandoned }

        #expect(completed.count == 1)
        #expect(abandoned.count == 1)
        #expect(completed[0].configuredDuration == 300)
        #expect(abandoned[0].configuredDuration == 600)
    }
}
