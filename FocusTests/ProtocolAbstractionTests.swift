import Testing
import Foundation
@testable import FocusCore

// MARK: - AuthorizationServiceProtocol Tests

@Suite("MockAuthorizationService Tests")
struct MockAuthorizationServiceTests {

    @Test("Initial status is notDetermined by default")
    func initialStatusNotDetermined() {
        let service = MockAuthorizationService()
        #expect(service.authorizationStatus == .notDetermined)
    }

    @Test("Initial status can be configured")
    func initialStatusConfigurable() {
        let approved = MockAuthorizationService(initialStatus: .approved)
        #expect(approved.authorizationStatus == .approved)

        let denied = MockAuthorizationService(initialStatus: .denied)
        #expect(denied.authorizationStatus == .denied)
    }

    @Test("Request authorization transitions to approved")
    func requestAuthorizationApproves() async throws {
        let service = MockAuthorizationService(shouldApprove: true)
        #expect(service.authorizationStatus == .notDetermined)

        try await service.requestAuthorization()
        #expect(service.authorizationStatus == .approved)
        #expect(service.requestAuthorizationCallCount == 1)
    }

    @Test("Request authorization transitions to denied")
    func requestAuthorizationDenies() async throws {
        let service = MockAuthorizationService(shouldApprove: false)
        #expect(service.authorizationStatus == .notDetermined)

        try await service.requestAuthorization()
        #expect(service.authorizationStatus == .denied)
        #expect(service.requestAuthorizationCallCount == 1)
    }

    @Test("Request authorization throws when shouldApprove is nil")
    func requestAuthorizationThrows() async {
        let service = MockAuthorizationService(shouldApprove: nil)

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is MockAuthorizationService.MockAuthorizationError)
        }
        #expect(service.requestAuthorizationCallCount == 1)
    }

    @Test("Request authorization throws custom error")
    func requestAuthorizationCustomError() async {
        let service = MockAuthorizationService(shouldApprove: nil)
        struct CustomError: Error {}
        service.errorToThrow = CustomError()

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is CustomError)
        }
    }

    @Test("Multiple authorization requests update count")
    func multipleAuthorizationRequests() async throws {
        let service = MockAuthorizationService(shouldApprove: true)

        try await service.requestAuthorization()
        try await service.requestAuthorization()
        try await service.requestAuthorization()

        #expect(service.requestAuthorizationCallCount == 3)
        #expect(service.authorizationStatus == .approved)
    }

    @Test("Reset clears call counts and state")
    func resetClearsState() async throws {
        let service = MockAuthorizationService(shouldApprove: true)
        try await service.requestAuthorization()

        #expect(service.authorizationStatus == .approved)
        #expect(service.requestAuthorizationCallCount == 1)

        service.reset()
        #expect(service.authorizationStatus == .notDetermined)
        #expect(service.requestAuthorizationCallCount == 0)
    }

    @Test("Reset to specific status")
    func resetToSpecificStatus() async throws {
        let service = MockAuthorizationService(shouldApprove: true)
        try await service.requestAuthorization()

        service.reset(to: .denied)
        #expect(service.authorizationStatus == .denied)
    }

    @Test("AuthorizationStatus enum raw values")
    func authorizationStatusRawValues() {
        #expect(AuthorizationStatus.notDetermined.rawValue == "notDetermined")
        #expect(AuthorizationStatus.approved.rawValue == "approved")
        #expect(AuthorizationStatus.denied.rawValue == "denied")
        #expect(AuthorizationStatus.allCases.count == 3)
    }

    @Test("Mock conforms to AuthorizationServiceProtocol")
    func mockConformsToProtocol() {
        let service: AuthorizationServiceProtocol = MockAuthorizationService()
        #expect(service.authorizationStatus == .notDetermined)
    }
}

// MARK: - ShieldServiceProtocol Tests

@Suite("MockShieldService Tests")
struct MockShieldServiceTests {

    @Test("Initially no stores are shielding")
    func initialStateNoShielding() {
        let service = MockShieldService()
        #expect(service.storeStates.isEmpty)
        #expect(service.isShielding(storeName: "test") == false)
    }

    @Test("Apply shields creates store state")
    func applyShieldsCreatesState() {
        let service = MockShieldService()
        let appTokens: Set<Data> = [Data([0x01]), Data([0x02])]
        let catTokens: Set<Data> = [Data([0x03])]
        let webTokens: Set<Data> = [Data([0x04])]

        service.applyShields(
            storeName: "work",
            applications: appTokens,
            categories: catTokens,
            webDomains: webTokens
        )

        #expect(service.isShielding(storeName: "work") == true)
        #expect(service.storeStates["work"]?.applications == appTokens)
        #expect(service.storeStates["work"]?.categories == catTokens)
        #expect(service.storeStates["work"]?.webDomains == webTokens)
        #expect(service.applyShieldsCalls.count == 1)
    }

    @Test("Apply shields with nil values")
    func applyShieldsNilValues() {
        let service = MockShieldService()

        service.applyShields(
            storeName: "empty",
            applications: nil,
            categories: nil,
            webDomains: nil
        )

        #expect(service.isShielding(storeName: "empty") == true)
        #expect(service.storeStates["empty"]?.applications == nil)
        #expect(service.storeStates["empty"]?.categories == nil)
        #expect(service.storeStates["empty"]?.webDomains == nil)
    }

    @Test("Clear shields removes store state")
    func clearShieldsRemovesState() {
        let service = MockShieldService()
        service.applyShields(
            storeName: "work",
            applications: [Data([0x01])],
            categories: nil,
            webDomains: nil
        )
        #expect(service.isShielding(storeName: "work") == true)

        service.clearShields(storeName: "work")
        #expect(service.isShielding(storeName: "work") == false)
        #expect(service.clearShieldsCalls == ["work"])
    }

    @Test("Multiple stores are independent")
    func multipleStoresIndependent() {
        let service = MockShieldService()

        service.applyShields(
            storeName: "work",
            applications: [Data([0x01])],
            categories: nil,
            webDomains: nil
        )
        service.applyShields(
            storeName: "evening",
            applications: [Data([0x02])],
            categories: nil,
            webDomains: nil
        )

        #expect(service.isShielding(storeName: "work") == true)
        #expect(service.isShielding(storeName: "evening") == true)

        // Clear one, other remains
        service.clearShields(storeName: "work")
        #expect(service.isShielding(storeName: "work") == false)
        #expect(service.isShielding(storeName: "evening") == true)
    }

    @Test("Apply shields records all calls")
    func applyShieldsRecordsCalls() {
        let service = MockShieldService()

        service.applyShields(storeName: "a", applications: nil, categories: nil, webDomains: nil)
        service.applyShields(storeName: "b", applications: nil, categories: nil, webDomains: nil)

        #expect(service.applyShieldsCalls.count == 2)
        #expect(service.applyShieldsCalls[0].storeName == "a")
        #expect(service.applyShieldsCalls[1].storeName == "b")
    }

    @Test("isShielding records all calls")
    func isShieldingRecordsCalls() {
        let service = MockShieldService()
        _ = service.isShielding(storeName: "test1")
        _ = service.isShielding(storeName: "test2")
        _ = service.isShielding(storeName: "test1")

        #expect(service.isShieldingCalls.count == 3)
        #expect(service.isShieldingCalls == ["test1", "test2", "test1"])
    }

    @Test("Updating shields overwrites previous state")
    func updatingShieldsOverwrites() {
        let service = MockShieldService()
        let oldTokens: Set<Data> = [Data([0x01])]
        let newTokens: Set<Data> = [Data([0x02]), Data([0x03])]

        service.applyShields(storeName: "work", applications: oldTokens, categories: nil, webDomains: nil)
        #expect(service.storeStates["work"]?.applications == oldTokens)

        service.applyShields(storeName: "work", applications: newTokens, categories: nil, webDomains: nil)
        #expect(service.storeStates["work"]?.applications == newTokens)
        #expect(service.applyShieldsCalls.count == 2)
    }

    @Test("Reset clears all state and calls")
    func resetClearsAll() {
        let service = MockShieldService()
        service.applyShields(storeName: "test", applications: nil, categories: nil, webDomains: nil)
        _ = service.isShielding(storeName: "test")
        service.clearShields(storeName: "test")

        service.reset()
        #expect(service.storeStates.isEmpty)
        #expect(service.applyShieldsCalls.isEmpty)
        #expect(service.clearShieldsCalls.isEmpty)
        #expect(service.isShieldingCalls.isEmpty)
    }

    @Test("Mock conforms to ShieldServiceProtocol")
    func mockConformsToProtocol() {
        let service: ShieldServiceProtocol = MockShieldService()
        service.applyShields(storeName: "test", applications: nil, categories: nil, webDomains: nil)
        #expect(service.isShielding(storeName: "test") == true)
    }

    @Test("Shield all three dimensions for complete blocking")
    func shieldAllThreeDimensions() {
        let service = MockShieldService()
        let apps: Set<Data> = [Data([0x01])]
        let cats: Set<Data> = [Data([0x02])]
        let webs: Set<Data> = [Data([0x03])]

        service.applyShields(storeName: "complete", applications: apps, categories: cats, webDomains: webs)

        let state = service.storeStates["complete"]
        #expect(state?.applications != nil)
        #expect(state?.categories != nil)
        #expect(state?.webDomains != nil)
    }
}

// MARK: - MonitoringServiceProtocol Tests

@Suite("MockMonitoringService Tests")
struct MockMonitoringServiceTests {

    @Test("Initially no active monitors")
    func initialStateNoMonitors() {
        let service = MockMonitoringService()
        #expect(service.activeMonitors.isEmpty)
        #expect(service.monitorSchedules.isEmpty)
    }

    @Test("Start monitoring adds to active monitors")
    func startMonitoringAdds() throws {
        let service = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        try service.startMonitoring(activityName: "work", schedule: schedule)

        #expect(service.activeMonitors.contains("work"))
        #expect(service.monitorSchedules["work"] == schedule)
        #expect(service.startMonitoringCalls.count == 1)
    }

    @Test("Stop monitoring removes from active monitors")
    func stopMonitoringRemoves() throws {
        let service = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        try service.startMonitoring(activityName: "work", schedule: schedule)
        #expect(service.activeMonitors.contains("work"))

        service.stopMonitoring(activityNames: ["work"])
        #expect(!service.activeMonitors.contains("work"))
        #expect(service.stopMonitoringCalls.count == 1)
    }

    @Test("Stop multiple monitors at once")
    func stopMultipleMonitors() throws {
        let service = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        try service.startMonitoring(activityName: "a", schedule: schedule)
        try service.startMonitoring(activityName: "b", schedule: schedule)
        try service.startMonitoring(activityName: "c", schedule: schedule)

        service.stopMonitoring(activityNames: ["a", "c"])
        #expect(service.activeMonitors == ["b"])
    }

    @Test("Schedule limit enforcement at 20")
    func scheduleLimitEnforcement() throws {
        let service = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 0, startMinute: 0, endHour: 1, endMinute: 0)

        // Fill up to the limit
        for i in 0..<20 {
            try service.startMonitoring(activityName: "activity_\(i)", schedule: schedule)
        }
        #expect(service.activeMonitors.count == 20)

        // 21st should fail
        do {
            try service.startMonitoring(activityName: "activity_20", schedule: schedule)
            Issue.record("Expected MonitoringError.scheduleLimitReached")
        } catch {
            #expect(error is MonitoringError)
            if let monitoringError = error as? MonitoringError {
                switch monitoringError {
                case .scheduleLimitReached:
                    break // Expected
                default:
                    Issue.record("Expected scheduleLimitReached, got \(monitoringError)")
                }
            }
        }
        #expect(service.activeMonitors.count == 20)
    }

    @Test("Re-registering existing monitor replaces schedule")
    func reRegisterReplacesSchedule() throws {
        let service = MockMonitoringService()
        let schedule1 = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let schedule2 = ScheduleConfig(startHour: 22, startMinute: 0, endHour: 7, endMinute: 0)

        try service.startMonitoring(activityName: "work", schedule: schedule1)
        try service.startMonitoring(activityName: "work", schedule: schedule2)

        #expect(service.monitorSchedules["work"] == schedule2)
        #expect(service.activeMonitors.count == 1)
        #expect(service.startMonitoringCalls.count == 2)
    }

    @Test("Custom error throwing")
    func customErrorThrowing() throws {
        let service = MockMonitoringService()
        service.shouldThrowOnStart = true

        let schedule = ScheduleConfig(startHour: 0, startMinute: 0, endHour: 1, endMinute: 0)

        do {
            try service.startMonitoring(activityName: "test", schedule: schedule)
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is MonitoringError)
        }
        #expect(service.activeMonitors.isEmpty)
        #expect(service.startMonitoringCalls.count == 1) // Call is recorded even when throwing
    }

    @Test("ScheduleConfig equality")
    func scheduleConfigEquality() {
        let a = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let b = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let c = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 18, endMinute: 0)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("ScheduleConfig with optional warning time")
    func scheduleConfigWarningTime() {
        let withWarning = ScheduleConfig(
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0,
            repeats: true,
            warningTimeMinutes: 15
        )
        #expect(withWarning.warningTimeMinutes == 15)

        let withoutWarning = ScheduleConfig(
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(withoutWarning.warningTimeMinutes == nil)
    }

    @Test("Reset clears all state and calls")
    func resetClearsAll() throws {
        let service = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 0, startMinute: 0, endHour: 1, endMinute: 0)
        try service.startMonitoring(activityName: "test", schedule: schedule)
        service.stopMonitoring(activityNames: ["test"])

        service.reset()
        #expect(service.monitorSchedules.isEmpty)
        #expect(service.startMonitoringCalls.isEmpty)
        #expect(service.stopMonitoringCalls.isEmpty)
        #expect(service.shouldThrowOnStart == false)
    }

    @Test("Mock conforms to MonitoringServiceProtocol")
    func mockConformsToProtocol() throws {
        let service: MonitoringServiceProtocol = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        try service.startMonitoring(activityName: "test", schedule: schedule)
        #expect(service.activeMonitors.contains("test"))
    }

    @Test("Stop monitoring non-existent activity is safe")
    func stopNonExistentActivity() {
        let service = MockMonitoringService()
        service.stopMonitoring(activityNames: ["nonexistent"])
        #expect(service.stopMonitoringCalls.count == 1)
        #expect(service.activeMonitors.isEmpty)
    }

    @Test("Active monitors returns sorted names")
    func activeMonitorsSorted() throws {
        let service = MockMonitoringService()
        let schedule = ScheduleConfig(startHour: 0, startMinute: 0, endHour: 1, endMinute: 0)

        try service.startMonitoring(activityName: "charlie", schedule: schedule)
        try service.startMonitoring(activityName: "alpha", schedule: schedule)
        try service.startMonitoring(activityName: "bravo", schedule: schedule)

        #expect(service.activeMonitors == ["alpha", "bravo", "charlie"])
    }
}

// MARK: - LiveActivityServiceProtocol Tests

@Suite("MockLiveActivityService Tests")
struct MockLiveActivityServiceTests {

    @Test("Initially no activities and enabled")
    func initialState() {
        let service = MockLiveActivityService()
        #expect(service.activities.isEmpty)
        #expect(service.areActivitiesEnabled == true)
    }

    @Test("Start break activity creates record")
    func startBreakActivity() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 300, sessionName: "Work")
        let state = BreakActivityState(
            endDate: Date().addingTimeInterval(300),
            remainingSeconds: 300
        )

        let id = try service.startBreakActivity(attributes: attrs, state: state)

        #expect(!id.isEmpty)
        #expect(service.activities[id] != nil)
        #expect(service.activities[id]?.isActive == true)
        #expect(service.activities[id]?.attributes == attrs)
        #expect(service.activities[id]?.currentState == state)
        #expect(service.startCalls.count == 1)
    }

    @Test("Update break activity changes state")
    func updateBreakActivity() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 300)
        let initialState = BreakActivityState(
            endDate: Date().addingTimeInterval(300),
            remainingSeconds: 300
        )

        let id = try service.startBreakActivity(attributes: attrs, state: initialState)

        let updatedState = BreakActivityState(
            endDate: Date().addingTimeInterval(150),
            remainingSeconds: 150
        )
        service.updateBreakActivity(id: id, state: updatedState)

        #expect(service.activities[id]?.currentState == updatedState)
        #expect(service.activities[id]?.isActive == true)
        #expect(service.updateCalls.count == 1)
    }

    @Test("End break activity marks as inactive")
    func endBreakActivity() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 300)
        let state = BreakActivityState(
            endDate: Date().addingTimeInterval(300),
            remainingSeconds: 300
        )

        let id = try service.startBreakActivity(attributes: attrs, state: state)
        service.endBreakActivity(id: id, dismissalPolicy: .immediate)

        #expect(service.activities[id]?.isActive == false)
        #expect(service.activities[id]?.dismissalPolicy == .immediate)
        #expect(service.endCalls.count == 1)
    }

    @Test("End with different dismissal policies")
    func endWithDismissalPolicies() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 60)
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 0)

        let id1 = try service.startBreakActivity(attributes: attrs, state: state)
        service.endBreakActivity(id: id1, dismissalPolicy: .default)
        #expect(service.activities[id1]?.dismissalPolicy == .default)

        let id2 = try service.startBreakActivity(attributes: attrs, state: state)
        service.endBreakActivity(id: id2, dismissalPolicy: .immediate)
        #expect(service.activities[id2]?.dismissalPolicy == .immediate)

        let futureDate = Date().addingTimeInterval(3600)
        let id3 = try service.startBreakActivity(attributes: attrs, state: state)
        service.endBreakActivity(id: id3, dismissalPolicy: .after(futureDate))
        #expect(service.activities[id3]?.dismissalPolicy == .after(futureDate))
    }

    @Test("Cleanup removes inactive activities")
    func cleanupRemovesInactive() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 60)
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 0)

        let id1 = try service.startBreakActivity(attributes: attrs, state: state)
        let id2 = try service.startBreakActivity(attributes: attrs, state: state)

        // End one activity
        service.endBreakActivity(id: id1, dismissalPolicy: .immediate)

        service.cleanupOrphanedActivities()
        #expect(service.cleanupCallCount == 1)
        #expect(service.activities[id1] == nil) // Removed
        #expect(service.activities[id2] != nil) // Still active
    }

    @Test("Throws when activities not enabled")
    func throwsWhenDisabled() throws {
        let service = MockLiveActivityService()
        service.areActivitiesEnabled = false

        let attrs = BreakActivityAttributes(breakDuration: 60)
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 0)

        do {
            _ = try service.startBreakActivity(attributes: attrs, state: state)
            Issue.record("Expected error")
        } catch {
            #expect(error is LiveActivityError)
        }
        #expect(service.startCalls.count == 1) // Call is recorded even on failure
    }

    @Test("Throws when configured to fail")
    func throwsWhenConfiguredToFail() {
        let service = MockLiveActivityService()
        service.shouldThrowOnStart = true

        let attrs = BreakActivityAttributes(breakDuration: 60)
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 0)

        do {
            _ = try service.startBreakActivity(attributes: attrs, state: state)
            Issue.record("Expected error")
        } catch {
            #expect(error is LiveActivityError)
        }
    }

    @Test("Activity lifecycle - start, update, end")
    func fullLifecycle() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 180, sessionName: "Study")
        let startState = BreakActivityState(
            endDate: Date().addingTimeInterval(180),
            remainingSeconds: 180
        )

        // Start
        let id = try service.startBreakActivity(attributes: attrs, state: startState)
        #expect(service.activeActivities.count == 1)

        // Update
        let midState = BreakActivityState(
            endDate: Date().addingTimeInterval(90),
            remainingSeconds: 90
        )
        service.updateBreakActivity(id: id, state: midState)

        // End
        let finalState = BreakActivityState(
            endDate: Date(),
            remainingSeconds: 0,
            isActive: false
        )
        service.updateBreakActivity(id: id, state: finalState)
        service.endBreakActivity(id: id, dismissalPolicy: .immediate)

        #expect(service.activeActivities.count == 0)
        #expect(service.endedActivities.count == 1)
        #expect(service.startCalls.count == 1)
        #expect(service.updateCalls.count == 2)
        #expect(service.endCalls.count == 1)
    }

    @Test("Multiple activities tracked independently")
    func multipleActivitiesIndependent() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 60)
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 60)

        let id1 = try service.startBreakActivity(attributes: attrs, state: state)
        let id2 = try service.startBreakActivity(attributes: attrs, state: state)

        #expect(id1 != id2)
        #expect(service.activeActivities.count == 2)

        service.endBreakActivity(id: id1, dismissalPolicy: .immediate)
        #expect(service.activeActivities.count == 1)
        #expect(service.activities[id2]?.isActive == true)
    }

    @Test("BreakActivityAttributes Codable round-trip")
    func attributesCodable() throws {
        let original = BreakActivityAttributes(breakDuration: 300, sessionName: "Focus")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BreakActivityAttributes.self, from: data)

        #expect(decoded == original)
        #expect(decoded.breakDuration == 300)
        #expect(decoded.sessionName == "Focus")
    }

    @Test("BreakActivityState Codable round-trip")
    func stateCodable() throws {
        let date = Date()
        let original = BreakActivityState(endDate: date, remainingSeconds: 120, isActive: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BreakActivityState.self, from: data)

        #expect(decoded == original)
    }

    @Test("BreakActivityAttributes payload under 4KB")
    func attributesPayloadSize() throws {
        let attrs = BreakActivityAttributes(breakDuration: 300, sessionName: "Very Long Session Name")
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 300, isActive: true)

        let attrsData = try JSONEncoder().encode(attrs)
        let stateData = try JSONEncoder().encode(state)

        #expect(attrsData.count < 4096)
        #expect(stateData.count < 4096)
    }

    @Test("Reset clears all state")
    func resetClearsAll() throws {
        let service = MockLiveActivityService()
        let attrs = BreakActivityAttributes(breakDuration: 60)
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 0)
        let id = try service.startBreakActivity(attributes: attrs, state: state)
        service.updateBreakActivity(id: id, state: state)
        service.endBreakActivity(id: id, dismissalPolicy: .immediate)
        service.cleanupOrphanedActivities()

        service.reset()
        #expect(service.activities.isEmpty)
        #expect(service.startCalls.isEmpty)
        #expect(service.updateCalls.isEmpty)
        #expect(service.endCalls.isEmpty)
        #expect(service.cleanupCallCount == 0)
        #expect(service.areActivitiesEnabled == true)
    }

    @Test("Mock conforms to LiveActivityServiceProtocol")
    func mockConformsToProtocol() throws {
        let service: LiveActivityServiceProtocol = MockLiveActivityService()
        #expect(service.areActivitiesEnabled == true)
    }

    @Test("DismissalPolicy equality")
    func dismissalPolicyEquality() {
        let date = Date()
        #expect(DismissalPolicy.default == DismissalPolicy.default)
        #expect(DismissalPolicy.immediate == DismissalPolicy.immediate)
        #expect(DismissalPolicy.after(date) == DismissalPolicy.after(date))
        #expect(DismissalPolicy.default != DismissalPolicy.immediate)
    }

    @Test("Update non-existent activity is safe")
    func updateNonExistentActivity() {
        let service = MockLiveActivityService()
        let state = BreakActivityState(endDate: Date(), remainingSeconds: 0)
        service.updateBreakActivity(id: "nonexistent", state: state)
        #expect(service.updateCalls.count == 1)
    }

    @Test("End non-existent activity is safe")
    func endNonExistentActivity() {
        let service = MockLiveActivityService()
        service.endBreakActivity(id: "nonexistent", dismissalPolicy: .immediate)
        #expect(service.endCalls.count == 1)
    }
}

// MARK: - SharedStateService Tests

@Suite("SharedStateService Tests")
struct SharedStateServiceTests {

    /// Creates a SharedStateService with a unique in-memory UserDefaults.
    private func makeService(
        now: @escaping () -> Date = { Date() }
    ) -> (SharedStateService, UserDefaults) {
        let suiteName = "test.shared.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let service = SharedStateService(defaults: defaults, dateProvider: now)
        return (service, defaults)
    }

    @Test("Session active flag+timestamp pattern")
    func sessionActiveFlagTimestamp() {
        let (service, _) = makeService()

        #expect(service.isSessionActive() == false)

        service.setSessionActive(true)
        #expect(service.isSessionActive() == true)

        service.setSessionActive(false)
        #expect(service.isSessionActive() == false)
    }

    @Test("Break state flag+timestamp pattern")
    func breakStateFlagTimestamp() {
        let (service, _) = makeService()

        #expect(service.isOnBreak() == false)

        service.setOnBreak(true)
        #expect(service.isOnBreak() == true)

        service.setOnBreak(false)
        #expect(service.isOnBreak() == false)
    }

    @Test("Bypass active flag+timestamp pattern")
    func bypassActiveFlagTimestamp() {
        let (service, _) = makeService()

        #expect(service.isBypassActive() == false)

        service.setBypassActive(true)
        #expect(service.isBypassActive() == true)

        service.setBypassActive(false)
        #expect(service.isBypassActive() == false)
    }

    @Test("Focus mode active flag+timestamp pattern")
    func focusModeActiveFlagTimestamp() {
        let (service, _) = makeService()

        #expect(service.isFocusModeActive() == false)

        service.setFocusModeActive(true)
        #expect(service.isFocusModeActive() == true)

        service.setFocusModeActive(false)
        #expect(service.isFocusModeActive() == false)
    }

    @Test("Unlock request flag+timestamp pattern")
    func unlockRequestFlagTimestamp() {
        let (service, _) = makeService()

        #expect(service.isUnlockRequested() == false)

        service.setUnlockRequested(true)
        #expect(service.isUnlockRequested() == true)

        service.setUnlockRequested(false)
        #expect(service.isUnlockRequested() == false)
    }

    @Test("Flag without timestamp returns false")
    func flagWithoutTimestampReturnsFalse() {
        let suiteName = "test.shared.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Set the flag directly without timestamp
        defaults.set(true, forKey: SharedStateKey.isSessionActive.rawValue)

        let service = SharedStateService(defaults: defaults)
        #expect(service.isSessionActive() == false)
    }

    @Test("Flag with expiry - active within maxAge")
    func flagWithExpiryActive() {
        let now = Date()
        let (service, _) = makeService(now: { now })

        service.setFlag(true, flagKey: .isSessionActive, timestampKey: .sessionActiveTimestamp)

        let result = service.getFlagWithExpiry(
            flagKey: .isSessionActive,
            timestampKey: .sessionActiveTimestamp,
            maxAge: 3600 // 1 hour
        )
        #expect(result == true)
    }

    @Test("Flag with expiry - expired past maxAge")
    func flagWithExpiryExpired() {
        var currentTime = Date()
        let (service, _) = makeService(now: { currentTime })

        // Set flag at "current" time
        service.setFlag(true, flagKey: .isSessionActive, timestampKey: .sessionActiveTimestamp)

        // Advance time past the max age
        currentTime = currentTime.addingTimeInterval(3601) // Just past 1 hour

        let result = service.getFlagWithExpiry(
            flagKey: .isSessionActive,
            timestampKey: .sessionActiveTimestamp,
            maxAge: 3600 // 1 hour
        )
        #expect(result == false)
    }

    @Test("Timestamp-based expiry prevents stale state from crashes")
    func timestampBasedExpiryPreventsStaleness() {
        var currentTime = Date()
        let (service, _) = makeService(now: { currentTime })

        // Simulate: session marked active, then app crashes
        service.setSessionActive(true)
        #expect(service.isSessionActive() == true)

        // Much later, check with expiry
        currentTime = currentTime.addingTimeInterval(86400) // 24 hours later

        // Flag still reads as true (basic check)
        #expect(service.isSessionActive() == true)

        // But with expiry check, it's expired
        let expired = service.getFlagWithExpiry(
            flagKey: .isSessionActive,
            timestampKey: .sessionActiveTimestamp,
            maxAge: 3600 // 1 hour max
        )
        #expect(expired == false)
    }

    @Test("Get timestamp returns correct date")
    func getTimestampReturnsDate() {
        let now = Date()
        let (service, _) = makeService(now: { now })

        service.setSessionActive(true)

        let timestamp = service.getTimestamp(for: .sessionActiveTimestamp)
        #expect(timestamp != nil)
        // Should be approximately now (within 1 second)
        if let ts = timestamp {
            #expect(abs(ts.timeIntervalSince(now)) < 1.0)
        }
    }

    @Test("Get timestamp returns nil when not set")
    func getTimestampReturnsNil() {
        let (service, _) = makeService()
        let timestamp = service.getTimestamp(for: .sessionActiveTimestamp)
        #expect(timestamp == nil)
    }

    @Test("String operations")
    func stringOperations() {
        let (service, _) = makeService()

        service.setString("2026-03-30", forKey: .lastDayCheck)
        #expect(service.getString(forKey: .lastDayCheck) == "2026-03-30")

        service.setString(nil, forKey: .lastDayCheck)
        #expect(service.getString(forKey: .lastDayCheck) == nil)
    }

    @Test("Data operations")
    func dataOperations() {
        let (service, _) = makeService()
        let data = Data([0x01, 0x02, 0x03])

        service.setData(data, forKey: "testTokens")
        #expect(service.getData(forKey: "testTokens") == data)

        service.setData(nil, forKey: "testTokens")
        #expect(service.getData(forKey: "testTokens") == nil)
    }

    @Test("Remove specific key")
    func removeSpecificKey() {
        let (service, _) = makeService()

        service.setSessionActive(true)
        #expect(service.isSessionActive() == true)

        service.removeValue(forKey: .isSessionActive)
        #expect(service.isSessionActive() == false)
    }

    @Test("Remove all clears everything")
    func removeAllClearsEverything() {
        let (service, _) = makeService()

        service.setSessionActive(true)
        service.setOnBreak(true)
        service.setBypassActive(true)
        service.setFocusModeActive(true)
        service.setUnlockRequested(true)

        service.removeAll()

        #expect(service.isSessionActive() == false)
        #expect(service.isOnBreak() == false)
        #expect(service.isBypassActive() == false)
        #expect(service.isFocusModeActive() == false)
        #expect(service.isUnlockRequested() == false)
    }

    @Test("Overwrite behavior - new value replaces old")
    func overwriteBehavior() {
        let (service, _) = makeService()

        service.setSessionActive(true)
        #expect(service.isSessionActive() == true)

        service.setSessionActive(false)
        #expect(service.isSessionActive() == false)

        service.setSessionActive(true)
        #expect(service.isSessionActive() == true)
    }

    @Test("Concurrent access patterns - simulated cross-target")
    func concurrentAccessPatterns() {
        let suiteName = "test.shared.\(UUID().uuidString)"
        let defaults1 = UserDefaults(suiteName: suiteName)!
        let defaults2 = UserDefaults(suiteName: suiteName)!

        let service1 = SharedStateService(defaults: defaults1)
        let service2 = SharedStateService(defaults: defaults2)

        // Service 1 writes
        service1.setSessionActive(true)

        // Service 2 reads
        #expect(service2.isSessionActive() == true)

        // Service 2 writes
        service2.setSessionActive(false)

        // Service 1 reads the updated value
        #expect(service1.isSessionActive() == false)
    }

    @Test("ActiveSessionID string operations")
    func activeSessionIDOperations() {
        let (service, _) = makeService()
        let sessionID = UUID().uuidString

        service.setString(sessionID, forKey: .activeSessionID)
        #expect(service.getString(forKey: .activeSessionID) == sessionID)
    }

    @Test("Flag set to true with past timestamp returns false with expiry")
    func flagTrueWithPastTimestampExpiry() {
        var currentTime = Date()
        let (service, _) = makeService(now: { currentTime })

        // Set the flag in the "past"
        service.setSessionActive(true)

        // Advance time by 2 hours
        currentTime = currentTime.addingTimeInterval(7200)

        // With 1-hour expiry, should be expired
        let result = service.getFlagWithExpiry(
            flagKey: .isSessionActive,
            timestampKey: .sessionActiveTimestamp,
            maxAge: 3600
        )
        #expect(result == false)

        // Set again at "current" time — should be active
        service.setSessionActive(true)
        let result2 = service.getFlagWithExpiry(
            flagKey: .isSessionActive,
            timestampKey: .sessionActiveTimestamp,
            maxAge: 3600
        )
        #expect(result2 == true)
    }

    @Test("Flag set to false with future timestamp returns false")
    func flagFalseWithFutureTimestamp() {
        let (service, _) = makeService()

        // Set flag to true then false
        service.setSessionActive(true)
        service.setSessionActive(false)

        let result = service.getFlagWithExpiry(
            flagKey: .isSessionActive,
            timestampKey: .sessionActiveTimestamp,
            maxAge: 3600
        )
        #expect(result == false)
    }
}

// MARK: - TokenSerializer Tests

@Suite("TokenSerializer Tests")
struct TokenSerializerTests {

    @Test("Serialize set of tokens")
    func serializeTokenSet() {
        let tokens: Set<Data> = [Data([0x01, 0x02]), Data([0x03, 0x04])]
        let serialized = TokenSerializer.serialize(tokens: tokens)

        #expect(serialized != nil)
        #expect(!serialized!.isEmpty)
    }

    @Test("Serialize empty set returns nil")
    func serializeEmptySetReturnsNil() {
        let tokens: Set<Data> = []
        let serialized = TokenSerializer.serialize(tokens: tokens)
        #expect(serialized == nil)
    }

    @Test("Serialize array of tokens")
    func serializeTokenArray() {
        let tokens = [Data([0x01]), Data([0x02]), Data([0x03])]
        let serialized = TokenSerializer.serialize(tokenArray: tokens)

        #expect(serialized != nil)
        #expect(!serialized!.isEmpty)
    }

    @Test("Serialize empty array returns nil")
    func serializeEmptyArrayReturnsNil() {
        let tokens: [Data] = []
        let serialized = TokenSerializer.serialize(tokenArray: tokens)
        #expect(serialized == nil)
    }

    @Test("Deserialize valid data")
    func deserializeValidData() throws {
        let tokens: Set<Data> = [Data([0x01, 0x02]), Data([0x03, 0x04])]
        let serialized = TokenSerializer.serialize(tokens: tokens)!
        let deserialized = try TokenSerializer.deserialize(data: serialized)

        #expect(deserialized == tokens)
    }

    @Test("Deserialize round-trip preserves data")
    func deserializeRoundTrip() throws {
        let tokens: Set<Data> = [
            Data([0xDE, 0xAD, 0xBE, 0xEF]),
            Data([0xCA, 0xFE]),
            Data([0x01])
        ]
        let serialized = TokenSerializer.serialize(tokens: tokens)!
        let deserialized = try TokenSerializer.deserialize(data: serialized)

        #expect(deserialized == tokens)
    }

    @Test("Deserialize corrupted data throws decodingFailed")
    func deserializeCorruptedDataThrows() {
        let corruptedData = Data([0xFF, 0xFE, 0xFD])

        do {
            _ = try TokenSerializer.deserialize(data: corruptedData)
            Issue.record("Expected error to be thrown")
        } catch let error as TokenSerializationError {
            switch error {
            case .decodingFailed:
                break // Expected
            default:
                Issue.record("Expected decodingFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Deserialize empty array throws emptyResult")
    func deserializeEmptyArrayThrows() {
        // Encode an empty array
        let emptyArrayData = try! JSONEncoder().encode([Data]())

        do {
            _ = try TokenSerializer.deserialize(data: emptyArrayData)
            Issue.record("Expected error to be thrown")
        } catch let error as TokenSerializationError {
            switch error {
            case .emptyResult:
                break // Expected
            default:
                Issue.record("Expected emptyResult, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Safely update tokens with valid data succeeds")
    func safelyUpdateValidData() {
        let suiteName = "test.tokens.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let tokens: Set<Data> = [Data([0x01]), Data([0x02])]
        let serialized = TokenSerializer.serialize(tokens: tokens)!

        let result = TokenSerializer.safelyUpdateTokens(
            serialized,
            forKey: "appTokens",
            in: defaults
        )

        #expect(result == true)
        #expect(defaults.data(forKey: "appTokens") == serialized)
    }

    @Test("Safely update tokens with nil preserves existing")
    func safelyUpdateNilPreservesExisting() {
        let suiteName = "test.tokens.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Set initial valid data
        let tokens: Set<Data> = [Data([0x01])]
        let serialized = TokenSerializer.serialize(tokens: tokens)!
        defaults.set(serialized, forKey: "appTokens")

        // Attempt to overwrite with nil
        let result = TokenSerializer.safelyUpdateTokens(
            nil,
            forKey: "appTokens",
            in: defaults
        )

        #expect(result == false)
        #expect(defaults.data(forKey: "appTokens") == serialized) // Preserved
    }

    @Test("Safely update tokens with empty data preserves existing")
    func safelyUpdateEmptyPreservesExisting() {
        let suiteName = "test.tokens.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Set initial valid data
        let tokens: Set<Data> = [Data([0x01])]
        let serialized = TokenSerializer.serialize(tokens: tokens)!
        defaults.set(serialized, forKey: "appTokens")

        // Attempt to overwrite with empty data
        let result = TokenSerializer.safelyUpdateTokens(
            Data(),
            forKey: "appTokens",
            in: defaults
        )

        #expect(result == false)
        #expect(defaults.data(forKey: "appTokens") == serialized) // Preserved
    }

    @Test("Safely update tokens with corrupted data preserves existing")
    func safelyUpdateCorruptedPreservesExisting() {
        let suiteName = "test.tokens.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Set initial valid data
        let tokens: Set<Data> = [Data([0x01])]
        let serialized = TokenSerializer.serialize(tokens: tokens)!
        defaults.set(serialized, forKey: "appTokens")

        // Attempt to overwrite with corrupted data
        let result = TokenSerializer.safelyUpdateTokens(
            Data([0xFF, 0xFE]),
            forKey: "appTokens",
            in: defaults
        )

        #expect(result == false)
        #expect(defaults.data(forKey: "appTokens") == serialized) // Preserved
    }

    @Test("Safely update tokens with empty array encoding preserves existing")
    func safelyUpdateEmptyArrayPreservesExisting() {
        let suiteName = "test.tokens.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Set initial valid data
        let tokens: Set<Data> = [Data([0x01])]
        let serialized = TokenSerializer.serialize(tokens: tokens)!
        defaults.set(serialized, forKey: "appTokens")

        // Attempt to overwrite with encoded empty array
        let emptyArrayData = try! JSONEncoder().encode([Data]())
        let result = TokenSerializer.safelyUpdateTokens(
            emptyArrayData,
            forKey: "appTokens",
            in: defaults
        )

        #expect(result == false)
        #expect(defaults.data(forKey: "appTokens") == serialized) // Preserved
    }

    @Test("Valid new data overwrites valid old data")
    func validNewDataOverwritesOld() {
        let suiteName = "test.tokens.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Set initial valid data
        let oldTokens: Set<Data> = [Data([0x01])]
        let oldSerialized = TokenSerializer.serialize(tokens: oldTokens)!
        defaults.set(oldSerialized, forKey: "appTokens")

        // Overwrite with new valid data
        let newTokens: Set<Data> = [Data([0x02]), Data([0x03])]
        let newSerialized = TokenSerializer.serialize(tokens: newTokens)!
        let result = TokenSerializer.safelyUpdateTokens(
            newSerialized,
            forKey: "appTokens",
            in: defaults
        )

        #expect(result == true)
        #expect(defaults.data(forKey: "appTokens") == newSerialized)
    }

    @Test("isValid returns true for valid data")
    func isValidTrueForValid() {
        let tokens: Set<Data> = [Data([0x01])]
        let serialized = TokenSerializer.serialize(tokens: tokens)
        #expect(TokenSerializer.isValid(data: serialized) == true)
    }

    @Test("isValid returns false for nil")
    func isValidFalseForNil() {
        #expect(TokenSerializer.isValid(data: nil) == false)
    }

    @Test("isValid returns false for empty data")
    func isValidFalseForEmpty() {
        #expect(TokenSerializer.isValid(data: Data()) == false)
    }

    @Test("isValid returns false for corrupted data")
    func isValidFalseForCorrupted() {
        #expect(TokenSerializer.isValid(data: Data([0xFF, 0xFE])) == false)
    }

    @Test("isValid returns false for empty array encoding")
    func isValidFalseForEmptyArray() {
        let emptyArrayData = try! JSONEncoder().encode([Data]())
        #expect(TokenSerializer.isValid(data: emptyArrayData) == false)
    }

    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        let decodingError = TokenSerializationError.decodingFailed(
            NSError(domain: "test", code: 0, userInfo: nil)
        )
        #expect(decodingError.localizedDescription.contains("decoding failed"))

        let emptyError = TokenSerializationError.emptyResult
        #expect(emptyError.localizedDescription.contains("empty"))

        let noDataError = TokenSerializationError.noData
        #expect(noDataError.localizedDescription.contains("No data"))
    }
}
