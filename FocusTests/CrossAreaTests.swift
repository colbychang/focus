import Testing
import Foundation
import SwiftData
@testable import FocusCore

// MARK: - Focus Session Recorder Tests

@Suite("FocusSessionRecorder")
struct FocusSessionRecorderTests {

    // MARK: - Helpers

    /// Creates an in-memory model container for testing.
    @MainActor
    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    /// Creates a FocusSessionRecorder with a fresh UserDefaults suite.
    private func makeRecorder(
        suiteName: String = UUID().uuidString,
        dateProvider: @escaping () -> Date = { Date() }
    ) -> (FocusSessionRecorder, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let recorder = FocusSessionRecorder(defaults: defaults, dateProvider: dateProvider)
        return (recorder, defaults)
    }

    // MARK: - Session Start/End Recording

    @Test("recordSessionStart writes active session start to UserDefaults")
    func testRecordSessionStart() {
        let profileId = UUID()
        let (recorder, _) = makeRecorder()

        recorder.recordSessionStart(profileId: profileId, profileName: "Work")

        let activeStarts = recorder.activeSessionStarts()
        #expect(activeStarts[profileId.uuidString] != nil)
        #expect(activeStarts[profileId.uuidString]?.profileName == "Work")
        #expect(activeStarts[profileId.uuidString]?.profileId == profileId)
    }

    @Test("recordSessionEnd moves session from active to pending")
    func testRecordSessionEnd() {
        let profileId = UUID()
        var currentTime = Date(timeIntervalSince1970: 1000)
        let (recorder, _) = makeRecorder(dateProvider: { currentTime })

        // Start session
        recorder.recordSessionStart(profileId: profileId, profileName: "Work")
        #expect(recorder.hasActiveSession(profileId: profileId))

        // End session 1 hour later
        currentTime = Date(timeIntervalSince1970: 4600)
        recorder.recordSessionEnd(profileId: profileId)

        // Active session should be gone
        #expect(!recorder.hasActiveSession(profileId: profileId))

        // Pending records should have the session
        let pending = recorder.pendingRecords()
        #expect(pending.count == 1)
        #expect(pending[0].profileId == profileId)
        #expect(pending[0].profileName == "Work")
        #expect(pending[0].startTimestamp == 1000)
        #expect(pending[0].endTimestamp == 4600)
        #expect(pending[0].duration == 3600)
    }

    @Test("recordSessionEnd with no active session is a no-op")
    func testRecordSessionEndNoActiveSession() {
        let profileId = UUID()
        let (recorder, _) = makeRecorder()

        recorder.recordSessionEnd(profileId: profileId)

        let pending = recorder.pendingRecords()
        #expect(pending.isEmpty)
    }

    // MARK: - Reconciliation

    @Test("reconcileSessions creates ScreenTimeEntry records from pending sessions")
    @MainActor
    func testReconcileSessions() throws {
        let modelContext = try makeModelContext()
        let profileId = UUID()
        var currentTime = Date(timeIntervalSince1970: 1000)
        let (recorder, _) = makeRecorder(dateProvider: { currentTime })

        // Record a complete session
        recorder.recordSessionStart(profileId: profileId, profileName: "Work")
        currentTime = Date(timeIntervalSince1970: 4600) // 1 hour later
        recorder.recordSessionEnd(profileId: profileId)

        // Reconcile
        let count = recorder.reconcileSessions(modelContext: modelContext)
        #expect(count == 1)

        // Verify ScreenTimeEntry was created
        let entries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].categoryName == "Focus Session: Work")
        #expect(entries[0].duration == 3600)

        // Pending should be cleared
        #expect(recorder.pendingRecords().isEmpty)
    }

    @Test("reconcileSessions handles multiple pending sessions")
    @MainActor
    func testReconcileMultipleSessions() throws {
        let modelContext = try makeModelContext()
        let profile1Id = UUID()
        let profile2Id = UUID()
        var currentTime = Date(timeIntervalSince1970: 1000)
        let (recorder, _) = makeRecorder(dateProvider: { currentTime })

        // Record first session
        recorder.recordSessionStart(profileId: profile1Id, profileName: "Work")
        currentTime = Date(timeIntervalSince1970: 4600)
        recorder.recordSessionEnd(profileId: profile1Id)

        // Record second session
        recorder.recordSessionStart(profileId: profile2Id, profileName: "Study")
        currentTime = Date(timeIntervalSince1970: 6400)
        recorder.recordSessionEnd(profileId: profile2Id)

        // Reconcile
        let count = recorder.reconcileSessions(modelContext: modelContext)
        #expect(count == 2)

        let entries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())
        #expect(entries.count == 2)
    }

    @Test("reconcileSessions with no pending records returns 0")
    @MainActor
    func testReconcileEmptyPending() throws {
        let modelContext = try makeModelContext()
        let (recorder, _) = makeRecorder()

        let count = recorder.reconcileSessions(modelContext: modelContext)
        #expect(count == 0)
    }

    @Test("reconcileSessions clears pending records after processing")
    @MainActor
    func testReconcileClearsPending() throws {
        let modelContext = try makeModelContext()
        let profileId = UUID()
        var currentTime = Date(timeIntervalSince1970: 1000)
        let (recorder, _) = makeRecorder(dateProvider: { currentTime })

        recorder.recordSessionStart(profileId: profileId, profileName: "Work")
        currentTime = Date(timeIntervalSince1970: 4600)
        recorder.recordSessionEnd(profileId: profileId)

        #expect(recorder.pendingRecords().count == 1)

        _ = recorder.reconcileSessions(modelContext: modelContext)

        #expect(recorder.pendingRecords().isEmpty)
    }

    // MARK: - Concurrent Sessions

    @Test("Concurrent sessions record independently with non-conflicting timestamps")
    func testConcurrentSessionRecording() {
        let profile1Id = UUID()
        let profile2Id = UUID()
        var currentTime = Date(timeIntervalSince1970: 1000)
        let (recorder, _) = makeRecorder(dateProvider: { currentTime })

        // Start both sessions at the same time
        recorder.recordSessionStart(profileId: profile1Id, profileName: "Work")
        recorder.recordSessionStart(profileId: profile2Id, profileName: "Study")

        // Both should be active
        #expect(recorder.hasActiveSession(profileId: profile1Id))
        #expect(recorder.hasActiveSession(profileId: profile2Id))

        // End first session after 30 min
        currentTime = Date(timeIntervalSince1970: 2800)
        recorder.recordSessionEnd(profileId: profile1Id)

        // First ended, second still active
        #expect(!recorder.hasActiveSession(profileId: profile1Id))
        #expect(recorder.hasActiveSession(profileId: profile2Id))

        // End second session after 1 hour
        currentTime = Date(timeIntervalSince1970: 4600)
        recorder.recordSessionEnd(profileId: profile2Id)

        // Both ended
        #expect(!recorder.hasActiveSession(profileId: profile1Id))
        #expect(!recorder.hasActiveSession(profileId: profile2Id))

        // Verify pending records
        let pending = recorder.pendingRecords()
        #expect(pending.count == 2)

        let workRecord = pending.first(where: { $0.profileName == "Work" })
        let studyRecord = pending.first(where: { $0.profileName == "Study" })

        #expect(workRecord != nil)
        #expect(studyRecord != nil)
        #expect(workRecord?.duration == 1800) // 30 minutes
        #expect(studyRecord?.duration == 3600) // 60 minutes
    }

    @Test("Concurrent sessions reconcile independently into SwiftData")
    @MainActor
    func testConcurrentSessionReconciliation() throws {
        let modelContext = try makeModelContext()
        let profile1Id = UUID()
        let profile2Id = UUID()
        var currentTime = Date(timeIntervalSince1970: 1000)
        let (recorder, _) = makeRecorder(dateProvider: { currentTime })

        // Start both sessions
        recorder.recordSessionStart(profileId: profile1Id, profileName: "Work")
        recorder.recordSessionStart(profileId: profile2Id, profileName: "Study")

        // End both
        currentTime = Date(timeIntervalSince1970: 2800)
        recorder.recordSessionEnd(profileId: profile1Id)
        currentTime = Date(timeIntervalSince1970: 4600)
        recorder.recordSessionEnd(profileId: profile2Id)

        // Reconcile
        let count = recorder.reconcileSessions(modelContext: modelContext)
        #expect(count == 2)

        let entries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())
        #expect(entries.count == 2)

        // Verify timestamps don't conflict
        let durations = entries.map(\.duration).sorted()
        #expect(durations == [1800, 3600])
    }
}

// MARK: - Authorization State Handler Tests

@Suite("AuthorizationStateHandler")
struct AuthorizationStateHandlerTests {

    @MainActor
    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test("Auth revocation clears all shields but preserves session data")
    @MainActor
    func testAuthRevocationPreservesData() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        // Create a profile and activate it
        let profile = FocusMode(name: "Work", isActive: true, isManuallyActivated: true)
        modelContext.insert(profile)

        // Create some historical session data
        let session = DeepFocusSession(
            startTime: Date().addingTimeInterval(-3600),
            configuredDuration: 3600,
            remainingSeconds: 0,
            status: .completed,
            focusMode: profile
        )
        modelContext.insert(session)

        let entry = ScreenTimeEntry(
            date: Date().addingTimeInterval(-3600),
            categoryName: "Focus Session: Work",
            duration: 3600
        )
        modelContext.insert(entry)
        try modelContext.save()

        // Apply shields to simulate active state
        shieldService.applyShields(storeName: profile.id.uuidString, applications: nil, categories: nil, webDomains: nil)

        let handler = AuthorizationStateHandler(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )

        // Revoke authorization
        let deactivatedCount = handler.handleAuthorizationRevoked()

        // Shields should be cleared
        #expect(deactivatedCount == 1)
        #expect(shieldService.clearShieldsCalls.contains(profile.id.uuidString))

        // Profile should be deactivated
        #expect(!profile.isActive)
        #expect(!profile.isManuallyActivated)

        // Historical data should be preserved
        let records = handler.countHistoricalRecords()
        #expect(records.screenTimeEntries == 1)
        #expect(records.deepFocusSessions == 1)
    }

    @Test("Auth revocation stops all monitoring")
    @MainActor
    func testAuthRevocationStopsMonitoring() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        let profile = FocusMode(name: "Work", isActive: true)
        profile.scheduleDays = [2, 3, 4, 5, 6] // Mon-Fri
        modelContext.insert(profile)
        try modelContext.save()

        let handler = AuthorizationStateHandler(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )

        _ = handler.handleAuthorizationRevoked()

        // Monitoring should be stopped
        #expect(monitoringService.stopMonitoringCalls.count == 1)
        #expect(monitoringService.stopMonitoringCalls[0] == [profile.id.uuidString])
    }

    @Test("Re-authorization preserves existing profiles and history")
    @MainActor
    func testReauthorizationPreservesData() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        // Create profiles and data
        let profile1 = FocusMode(name: "Work")
        let profile2 = FocusMode(name: "Study")
        modelContext.insert(profile1)
        modelContext.insert(profile2)

        let entry = ScreenTimeEntry(
            date: Date(),
            categoryName: "Focus Session: Work",
            duration: 3600
        )
        modelContext.insert(entry)
        try modelContext.save()

        let handler = AuthorizationStateHandler(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )

        // First revoke
        _ = handler.handleAuthorizationRevoked()

        // Then re-authorize
        let profileCount = handler.handleReauthorization()

        // All profiles should still exist
        #expect(profileCount == 2)

        // Historical data should be intact
        let records = handler.countHistoricalRecords()
        #expect(records.screenTimeEntries == 1)
    }

    @Test("Auth revocation with multiple active profiles deactivates all")
    @MainActor
    func testAuthRevocationMultipleActiveProfiles() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        let profile1 = FocusMode(name: "Work", isActive: true)
        let profile2 = FocusMode(name: "Study", isActive: true)
        let profile3 = FocusMode(name: "Evening", isActive: false)
        modelContext.insert(profile1)
        modelContext.insert(profile2)
        modelContext.insert(profile3)
        try modelContext.save()

        let handler = AuthorizationStateHandler(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )

        let deactivated = handler.handleAuthorizationRevoked()

        #expect(deactivated == 2) // Only the 2 active ones
        #expect(!profile1.isActive)
        #expect(!profile2.isActive)
        #expect(!profile3.isActive)

        // All 3 profiles should have shields cleared (even inactive for safety)
        #expect(shieldService.clearShieldsCalls.count == 3)
    }
}

// MARK: - Profile Deletion Preserves Sessions

@Suite("Profile Deletion Preserves Sessions")
struct ProfileDeletionPreservesSessionsTests {

    @MainActor
    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test("Deleting a profile preserves associated DeepFocusSessions with nullified relationship")
    @MainActor
    func testDeleteProfilePreservesDeepFocusSessions() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        // Create profile with sessions
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)

        let session1 = DeepFocusSession(
            startTime: Date().addingTimeInterval(-7200),
            configuredDuration: 3600,
            remainingSeconds: 0,
            status: .completed,
            focusMode: profile
        )
        let session2 = DeepFocusSession(
            startTime: Date().addingTimeInterval(-3600),
            configuredDuration: 1800,
            remainingSeconds: 0,
            status: .completed,
            focusMode: profile
        )
        modelContext.insert(session1)
        modelContext.insert(session2)
        try modelContext.save()

        // Delete profile
        let service = FocusModeService(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )
        try service.deleteProfile(id: profile.id)

        // Sessions should still exist (nullify delete rule)
        let sessions = try modelContext.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 2)

        // focusMode reference should be nil
        for session in sessions {
            #expect(session.focusMode == nil)
        }

        // Profile should be gone
        let profiles = try modelContext.fetch(FetchDescriptor<FocusMode>())
        #expect(profiles.isEmpty)
    }

    @Test("Deleting a profile preserves ScreenTimeEntry records")
    @MainActor
    func testDeleteProfilePreservesScreenTimeEntries() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        // Create profile
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)

        // Create screen time entries referencing the profile name
        let entry = ScreenTimeEntry(
            date: Date().addingTimeInterval(-3600),
            categoryName: "Focus Session: Work",
            duration: 3600
        )
        modelContext.insert(entry)
        try modelContext.save()

        // Delete profile
        let service = FocusModeService(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )
        try service.deleteProfile(id: profile.id)

        // ScreenTimeEntry should still exist
        let entries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].categoryName == "Focus Session: Work")
    }
}

// MARK: - Settings Change Propagation Tests

@Suite("Settings Change Propagation")
struct SettingsChangePropagationTests {

    @MainActor
    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test("Modifying a profile schedule re-registers monitoring")
    @MainActor
    func testScheduleChangeReregistersMonitoring() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        let service = FocusModeService(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )

        // Create profile with initial schedule
        let profile = try service.createProfile(name: "Work")
        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [2, 3, 4], // Mon-Wed
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0
        )

        // Verify monitoring started
        #expect(monitoringService.startMonitoringCalls.count == 1)

        // Change the schedule
        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [2, 3, 4, 5, 6], // Mon-Fri
            startHour: 8,
            startMinute: 0,
            endHour: 18,
            endMinute: 0
        )

        // Old schedule should be stopped and new one started
        #expect(monitoringService.stopMonitoringCalls.count == 2) // stop for first, stop for second
        #expect(monitoringService.startMonitoringCalls.count == 2)
    }

    @Test("Changing blocked apps on active profile updates shield store")
    @MainActor
    func testChangingBlockedAppsUpdatesStore() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        // Create and activate a profile
        let profile = FocusMode(name: "Work")
        modelContext.insert(profile)
        try modelContext.save()

        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile)
        #expect(profile.isActive)

        // Initial shield apply
        let initialCallCount = shieldService.applyShieldsCalls.count
        #expect(initialCallCount == 1)

        // Simulate changing blocked apps by updating tokens
        let newTokens = TokenSerializer.serialize(tokens: Set([Data([1, 2, 3])]))
        profile.serializedAppTokens = newTokens
        try modelContext.save()

        // Refresh shields on active profile
        activationService.refreshShieldsIfActive(profile: profile)

        // Should have called applyShields again with updated tokens
        #expect(shieldService.applyShieldsCalls.count == initialCallCount + 1)
    }

    @Test("Deleting a profile with active shields clears shield store")
    @MainActor
    func testDeleteActiveProfileClearsShields() throws {
        let modelContext = try makeModelContext()
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()

        let service = FocusModeService(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )

        let profile = try service.createProfile(name: "Work")

        // Activate manually
        let activationService = FocusModeActivationService(
            modelContext: modelContext,
            shieldService: shieldService
        )
        activationService.activate(profile: profile)
        #expect(shieldService.isShielding(storeName: profile.id.uuidString))

        // Delete profile
        try service.deleteProfile(id: profile.id)

        // Shields should be cleared
        #expect(shieldService.clearShieldsCalls.contains(profile.id.uuidString))
    }
}

// MARK: - Focus Session → Analytics Data Flow Tests (VAL-CROSS-003)

@Suite("Focus Session Analytics Flow")
struct FocusSessionAnalyticsFlowTests {

    @MainActor
    private func makeModelContext() throws -> ModelContext {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test("Simulated intervalDidStart/End creates session record with correct timestamps and duration")
    @MainActor
    func testIntervalStartEndCreatesSessionRecord() throws {
        let modelContext = try makeModelContext()
        let profileId = UUID()

        // Simulate: intervalDidStart at T=1000
        var currentTime = Date(timeIntervalSince1970: 1000)
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let recorder = FocusSessionRecorder(defaults: defaults, dateProvider: { currentTime })

        recorder.recordSessionStart(profileId: profileId, profileName: "Work")

        // Simulate: intervalDidEnd 1 hour later at T=4600
        currentTime = Date(timeIntervalSince1970: 4600)
        recorder.recordSessionEnd(profileId: profileId)

        // Reconcile into SwiftData
        let count = recorder.reconcileSessions(modelContext: modelContext)
        #expect(count == 1)

        // Verify session record
        let entries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].duration == 3600) // 1 hour, within 1-minute tolerance
        #expect(entries[0].categoryName == "Focus Session: Work")
        #expect(entries[0].date.timeIntervalSince1970 == 1000) // start time
    }

    @Test("Duration matches schedule length within tolerance")
    @MainActor
    func testDurationWithinTolerance() throws {
        let modelContext = try makeModelContext()
        let profileId = UUID()

        // Schedule: 9:00-17:00 (8 hours = 28800 seconds)
        let startTime: TimeInterval = 1000
        let scheduleDuration: TimeInterval = 28800 // 8 hours
        var currentTime = Date(timeIntervalSince1970: startTime)
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let recorder = FocusSessionRecorder(defaults: defaults, dateProvider: { currentTime })

        recorder.recordSessionStart(profileId: profileId, profileName: "Work")
        currentTime = Date(timeIntervalSince1970: startTime + scheduleDuration)
        recorder.recordSessionEnd(profileId: profileId)

        let count = recorder.reconcileSessions(modelContext: modelContext)
        #expect(count == 1)

        let entries = try modelContext.fetch(FetchDescriptor<ScreenTimeEntry>())
        let recordedDuration = entries[0].duration

        // Should match within 1-minute tolerance
        let tolerance: TimeInterval = 60
        #expect(abs(recordedDuration - scheduleDuration) <= tolerance)
    }
}

// MARK: - FocusNotificationService Tests

@Suite("FocusNotificationService")
struct FocusNotificationServiceTests {

    @Test("showActivation creates notification with correct message")
    @MainActor
    func testShowActivation() {
        let service = FocusNotificationService(autoDismissDuration: 10)
        service.showActivation(profileName: "Work")

        #expect(service.isShowingNotification)
        #expect(service.currentNotification?.message == "Work Focus activated")
        #expect(service.currentNotification?.isActivation == true)
        #expect(service.currentNotification?.profileName == "Work")
    }

    @Test("showDeactivation creates notification with correct message")
    @MainActor
    func testShowDeactivation() {
        let service = FocusNotificationService(autoDismissDuration: 10)
        service.showDeactivation(profileName: "Work")

        #expect(service.isShowingNotification)
        #expect(service.currentNotification?.message == "Work Focus ended")
        #expect(service.currentNotification?.isActivation == false)
        #expect(service.currentNotification?.profileName == "Work")
    }

    @Test("dismiss clears current notification")
    @MainActor
    func testDismiss() {
        let service = FocusNotificationService(autoDismissDuration: 10)
        service.showActivation(profileName: "Work")
        #expect(service.isShowingNotification)

        service.dismiss()
        #expect(!service.isShowingNotification)
        #expect(service.currentNotification == nil)
    }

    @Test("New notification replaces existing one")
    @MainActor
    func testNewNotificationReplacesExisting() {
        let service = FocusNotificationService(autoDismissDuration: 10)
        service.showActivation(profileName: "Work")
        let firstId = service.currentNotification?.id

        service.showDeactivation(profileName: "Study")
        let secondId = service.currentNotification?.id

        #expect(firstId != secondId)
        #expect(service.currentNotification?.message == "Study Focus ended")
    }
}

// MARK: - SessionRecord Tests

@Suite("SessionRecord")
struct SessionRecordTests {

    @Test("SessionRecord duration calculation")
    func testDurationCalculation() {
        var record = SessionRecord(
            profileId: UUID(),
            profileName: "Work",
            startTimestamp: 1000,
            endTimestamp: 4600
        )
        #expect(record.duration == 3600)

        // No end timestamp
        record = SessionRecord(
            profileId: UUID(),
            profileName: "Work",
            startTimestamp: 1000,
            endTimestamp: nil
        )
        #expect(record.duration == nil)

        // Zero duration (start equals end)
        record = SessionRecord(
            profileId: UUID(),
            profileName: "Work",
            startTimestamp: 1000,
            endTimestamp: 1000
        )
        #expect(record.duration == 0)
    }

    @Test("SessionRecord Codable round-trip")
    func testCodableRoundTrip() throws {
        let original = SessionRecord(
            profileId: UUID(),
            profileName: "Work Focus",
            startTimestamp: 1000,
            endTimestamp: 4600
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionRecord.self, from: data)

        #expect(decoded == original)
    }
}
