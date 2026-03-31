import Testing
import Foundation
import SwiftData
@testable import FocusCore

// MARK: - FocusModeActivationService Tests

/// Unit tests for FocusModeActivationService covering activation, deactivation,
/// no-op paths, multiple independent stores, and editing active profiles.
/// Validates VAL-FOCUS-006, VAL-FOCUS-007, VAL-FOCUS-012, VAL-FOCUS-014.
@Suite("FocusModeActivationService Tests", .serialized)
struct FocusModeActivationServiceTests {

    // MARK: - Test Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [config]
        )
    }

    @MainActor
    private func makeService() throws -> (FocusModeActivationService, MockShieldService, ModelContext) {
        let container = try makeContainer()
        let context = ModelContext(container)
        let shieldService = MockShieldService()
        let service = FocusModeActivationService(
            modelContext: context,
            shieldService: shieldService
        )
        return (service, shieldService, context)
    }

    @MainActor
    private func createProfile(
        context: ModelContext,
        name: String = "Work",
        apps: Data? = nil,
        categories: Data? = nil,
        webDomains: Data? = nil,
        isActive: Bool = false,
        isManuallyActivated: Bool = false
    ) -> FocusMode {
        let profile = FocusMode(
            name: name,
            serializedAppTokens: apps,
            serializedCategoryTokens: categories,
            serializedWebDomainTokens: webDomains,
            isActive: isActive,
            isManuallyActivated: isManuallyActivated
        )
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// Creates serialized token data from an array of byte arrays.
    private func makeTokenData(_ tokens: [[UInt8]]) -> Data? {
        let dataSet = Set(tokens.map { Data($0) })
        return TokenSerializer.serialize(tokens: dataSet)
    }

    // MARK: - Activation Tests (VAL-FOCUS-006)

    @Test("Activate applies shields on all 3 dimensions")
    @MainActor
    func testActivateAppliesShieldsAllDimensions() throws {
        let (service, shieldService, context) = try makeService()

        let sampleApps = makeTokenData([[1, 2, 3], [4, 5, 6]])
        let sampleCategories = makeTokenData([[10, 11]])
        let sampleWebDomains = makeTokenData([[20, 21, 22]])

        let profile = createProfile(
            context: context,
            name: "Work",
            apps: sampleApps,
            categories: sampleCategories,
            webDomains: sampleWebDomains
        )

        service.activate(profile: profile)

        // Verify shields were applied
        #expect(shieldService.applyShieldsCalls.count == 1)

        let call = shieldService.applyShieldsCalls.first!
        #expect(call.storeName == profile.id.uuidString)

        // Verify all three dimensions are set
        #expect(call.applications != nil)
        #expect(call.categories != nil)
        #expect(call.webDomains != nil)

        // Verify the correct number of tokens
        #expect(call.applications!.count == 2) // 2 app tokens
        #expect(call.categories!.count == 1) // 1 category token
        #expect(call.webDomains!.count == 1) // 1 web domain token

        // Verify model state
        #expect(profile.isActive == true)
        #expect(profile.isManuallyActivated == true)
    }

    @Test("Activate with no tokens sets nil dimensions")
    @MainActor
    func testActivateWithNoTokens() throws {
        let (service, shieldService, context) = try makeService()

        let profile = createProfile(context: context, name: "Empty")

        service.activate(profile: profile)

        #expect(shieldService.applyShieldsCalls.count == 1)
        let call = shieldService.applyShieldsCalls.first!
        #expect(call.applications == nil)
        #expect(call.categories == nil)
        #expect(call.webDomains == nil)

        #expect(profile.isActive == true)
        #expect(profile.isManuallyActivated == true)
    }

    @Test("Activate sets isManuallyActivated flag")
    @MainActor
    func testActivateSetsManualFlag() throws {
        let (service, _, context) = try makeService()
        let profile = createProfile(context: context)

        #expect(profile.isManuallyActivated == false)

        service.activate(profile: profile)

        #expect(profile.isManuallyActivated == true)
    }

    @Test("Activate uses profile UUID as store name")
    @MainActor
    func testActivateUsesUUIDStoreName() throws {
        let (service, shieldService, context) = try makeService()
        let profile = createProfile(context: context)

        service.activate(profile: profile)

        #expect(shieldService.applyShieldsCalls.first?.storeName == profile.id.uuidString)
    }

    // MARK: - Deactivation Tests (VAL-FOCUS-006)

    @Test("Deactivate clears named store")
    @MainActor
    func testDeactivateClearsNamedStore() throws {
        let (service, shieldService, context) = try makeService()
        let profile = createProfile(context: context, isActive: true, isManuallyActivated: true)

        service.deactivate(profile: profile)

        #expect(shieldService.clearShieldsCalls.count == 1)
        #expect(shieldService.clearShieldsCalls.first == profile.id.uuidString)
        #expect(profile.isActive == false)
        #expect(profile.isManuallyActivated == false)
    }

    @Test("Deactivate resets both isActive and isManuallyActivated")
    @MainActor
    func testDeactivateResetsBothFlags() throws {
        let (service, _, context) = try makeService()
        let profile = createProfile(
            context: context,
            isActive: true,
            isManuallyActivated: true
        )

        service.deactivate(profile: profile)

        #expect(profile.isActive == false)
        #expect(profile.isManuallyActivated == false)
    }

    // MARK: - No-Op Tests (VAL-FOCUS-006)

    @Test("Activating already-active profile is no-op")
    @MainActor
    func testActivateAlreadyActiveIsNoop() throws {
        let (service, shieldService, context) = try makeService()
        let profile = createProfile(
            context: context,
            isActive: true,
            isManuallyActivated: true
        )

        service.activate(profile: profile)

        // No shield calls should be made
        #expect(shieldService.applyShieldsCalls.isEmpty)
        #expect(profile.isActive == true)
    }

    @Test("Deactivating already-inactive profile is no-op")
    @MainActor
    func testDeactivateAlreadyInactiveIsNoop() throws {
        let (service, shieldService, context) = try makeService()
        let profile = createProfile(context: context, isActive: false)

        service.deactivate(profile: profile)

        // No shield calls should be made
        #expect(shieldService.clearShieldsCalls.isEmpty)
        #expect(profile.isActive == false)
    }

    // MARK: - Multiple Independent Stores Tests (VAL-FOCUS-007)

    @Test("Multiple profiles activate with independent stores")
    @MainActor
    func testMultipleProfilesIndependentStores() throws {
        let (service, shieldService, context) = try makeService()

        let tokenDataA = makeTokenData([[1, 2, 3]])
        let tokenDataB = makeTokenData([[4, 5, 6]])

        let profile1 = createProfile(
            context: context,
            name: "Work",
            apps: tokenDataA
        )
        let profile2 = createProfile(
            context: context,
            name: "Evening",
            apps: tokenDataB
        )

        // Activate both
        service.activate(profile: profile1)
        service.activate(profile: profile2)

        #expect(shieldService.applyShieldsCalls.count == 2)
        #expect(profile1.isActive == true)
        #expect(profile2.isActive == true)

        // Verify different store names
        let storeNames = shieldService.applyShieldsCalls.map(\.storeName)
        #expect(storeNames.contains(profile1.id.uuidString))
        #expect(storeNames.contains(profile2.id.uuidString))
        #expect(storeNames[0] != storeNames[1])

        // Verify independent stores exist
        #expect(shieldService.storeStates.count == 2)
    }

    @Test("Deactivating one profile does not affect another")
    @MainActor
    func testDeactivateOneDoesNotAffectAnother() throws {
        let (service, shieldService, context) = try makeService()

        let tokenDataA = makeTokenData([[1, 2, 3]])
        let tokenDataB = makeTokenData([[4, 5, 6]])

        let profile1 = createProfile(
            context: context,
            name: "Work",
            apps: tokenDataA
        )
        let profile2 = createProfile(
            context: context,
            name: "Evening",
            apps: tokenDataB
        )

        // Activate both
        service.activate(profile: profile1)
        service.activate(profile: profile2)

        #expect(shieldService.storeStates.count == 2)

        // Deactivate only profile1
        service.deactivate(profile: profile1)

        // Profile1 should be inactive, profile2 should still be active
        #expect(profile1.isActive == false)
        #expect(profile2.isActive == true)

        // Profile2's store should still exist
        #expect(shieldService.isShielding(storeName: profile2.id.uuidString) == true)
        #expect(shieldService.isShielding(storeName: profile1.id.uuidString) == false)
    }

    @Test("Store names are deterministic based on profile UUID")
    @MainActor
    func testStoreNamesDeterministic() throws {
        let (service, _, context) = try makeService()
        let profile = createProfile(context: context)

        let name1 = service.storeName(for: profile)
        let name2 = service.storeName(for: profile)

        #expect(name1 == name2)
        #expect(name1 == profile.id.uuidString)
    }

    // MARK: - Edit Active Profile Tests (VAL-FOCUS-012)

    @Test("Editing blocked apps on active profile updates store immediately")
    @MainActor
    func testEditActiveProfileUpdatesStore() throws {
        let (service, shieldService, context) = try makeService()

        let initialTokenData = makeTokenData([[1, 2, 3]])
        let profile = createProfile(
            context: context,
            name: "Work",
            apps: initialTokenData
        )

        // Activate the profile
        service.activate(profile: profile)
        #expect(shieldService.applyShieldsCalls.count == 1)

        // Edit the profile's blocked apps
        let newAppTokens = makeTokenData([[7, 8, 9], [10, 11, 12]])
        let newCategoryTokens = makeTokenData([[30, 31]])
        profile.serializedAppTokens = newAppTokens
        profile.serializedCategoryTokens = newCategoryTokens
        try? context.save()

        // Refresh shields for the active profile
        service.refreshShieldsIfActive(profile: profile)

        // Verify updated shields were applied
        #expect(shieldService.applyShieldsCalls.count == 2)
        let lastCall = shieldService.applyShieldsCalls.last!
        #expect(lastCall.storeName == profile.id.uuidString)
        #expect(lastCall.applications!.count == 2) // 2 new app tokens
        #expect(lastCall.categories!.count == 1) // 1 new category token
    }

    @Test("Refreshing shields on inactive profile is no-op")
    @MainActor
    func testRefreshShieldsInactiveProfileIsNoop() throws {
        let (service, shieldService, context) = try makeService()
        let profile = createProfile(context: context, isActive: false)

        service.refreshShieldsIfActive(profile: profile)

        #expect(shieldService.applyShieldsCalls.isEmpty)
    }

    // MARK: - Manual Activation Precedence Tests (VAL-FOCUS-014)

    @Test("Manual activation prevents intervalDidEnd from removing shields")
    @MainActor
    func testManualActivationPrecedenceOverSchedule() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let monitoringService = MockMonitoringService()
        let shieldService = MockShieldService()
        let sharedState = SharedStateService(defaults: UserDefaults.standard)

        let manager = ScheduleManager(
            monitoringService: monitoringService,
            shieldService: shieldService,
            sharedStateService: sharedState
        )

        // Create a profile with a Monday 9-17 schedule, manually activated
        let profile = FocusMode(
            name: "Work",
            scheduleDays: [2], // Monday
            scheduleStartHour: 9,
            scheduleStartMinute: 0,
            scheduleEndHour: 17,
            scheduleEndMinute: 0,
            isActive: true,
            isManuallyActivated: true
        )
        context.insert(profile)
        try context.save()

        // Simulate intervalDidEnd firing outside schedule (Monday 18:00)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 30 // Monday
        components.hour = 18
        components.minute = 0
        let mondayEvening = calendar.date(from: components)!

        let shouldRemove = manager.shouldRemoveShieldsOnIntervalEnd(
            activityName: manager.activityName(for: profile),
            profile: profile,
            currentDate: mondayEvening
        )

        // Manual activation takes precedence — should NOT remove shields
        #expect(shouldRemove == false)
    }

    @Test("Schedule-activated profile CAN be removed by intervalDidEnd outside schedule")
    @MainActor
    func testScheduleActivatedCanBeRemovedByIntervalEnd() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let monitoringService = MockMonitoringService()
        let shieldService = MockShieldService()
        let sharedState = SharedStateService(defaults: UserDefaults.standard)

        let manager = ScheduleManager(
            monitoringService: monitoringService,
            shieldService: shieldService,
            sharedStateService: sharedState
        )

        // Create a profile active but NOT manually activated (schedule-activated)
        let profile = FocusMode(
            name: "Work",
            scheduleDays: [2], // Monday
            scheduleStartHour: 9,
            scheduleStartMinute: 0,
            scheduleEndHour: 17,
            scheduleEndMinute: 0,
            isActive: true,
            isManuallyActivated: false
        )
        context.insert(profile)
        try context.save()

        // Simulate intervalDidEnd firing outside schedule (Monday 18:00)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 30 // Monday
        components.hour = 18
        components.minute = 0
        let mondayEvening = calendar.date(from: components)!

        let shouldRemove = manager.shouldRemoveShieldsOnIntervalEnd(
            activityName: manager.activityName(for: profile),
            profile: profile,
            currentDate: mondayEvening
        )

        // Schedule-activated — SHOULD remove shields outside schedule
        #expect(shouldRemove == true)
    }

    @Test("Manual activation within schedule prevents spurious intervalDidEnd")
    @MainActor
    func testManualActivationWithinSchedulePreventsSpuriousIntervalEnd() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let monitoringService = MockMonitoringService()
        let shieldService = MockShieldService()
        let sharedState = SharedStateService(defaults: UserDefaults.standard)

        let manager = ScheduleManager(
            monitoringService: monitoringService,
            shieldService: shieldService,
            sharedStateService: sharedState
        )

        // Create a profile manually activated during schedule hours
        let profile = FocusMode(
            name: "Work",
            scheduleDays: [2], // Monday
            scheduleStartHour: 9,
            scheduleStartMinute: 0,
            scheduleEndHour: 17,
            scheduleEndMinute: 0,
            isActive: true,
            isManuallyActivated: true
        )
        context.insert(profile)
        try context.save()

        // Simulate intervalDidEnd firing within schedule (Monday 12:00, spurious)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 30 // Monday
        components.hour = 12
        components.minute = 0
        let mondayNoon = calendar.date(from: components)!

        let shouldRemove = manager.shouldRemoveShieldsOnIntervalEnd(
            activityName: manager.activityName(for: profile),
            profile: profile,
            currentDate: mondayNoon
        )

        // Manual activation — should NOT remove shields regardless of time
        #expect(shouldRemove == false)
    }

    // MARK: - Activate/Deactivate Cycle Tests

    @Test("Activate then deactivate then reactivate works correctly")
    @MainActor
    func testActivateDeactivateReactivateCycle() throws {
        let (service, shieldService, context) = try makeService()

        let sampleData = makeTokenData([[1, 2, 3]])
        let profile = createProfile(
            context: context,
            name: "Work",
            apps: sampleData
        )

        // Activate
        service.activate(profile: profile)
        #expect(profile.isActive == true)
        #expect(shieldService.applyShieldsCalls.count == 1)

        // Deactivate
        service.deactivate(profile: profile)
        #expect(profile.isActive == false)
        #expect(shieldService.clearShieldsCalls.count == 1)

        // Reactivate
        service.activate(profile: profile)
        #expect(profile.isActive == true)
        #expect(shieldService.applyShieldsCalls.count == 2)
    }

    // MARK: - isActive Query Tests

    @Test("isActive returns correct state")
    @MainActor
    func testIsActiveQuery() throws {
        let (service, _, context) = try makeService()
        let profile = createProfile(context: context, isActive: false)

        #expect(service.isActive(profile: profile) == false)

        service.activate(profile: profile)
        #expect(service.isActive(profile: profile) == true)

        service.deactivate(profile: profile)
        #expect(service.isActive(profile: profile) == false)
    }
}
