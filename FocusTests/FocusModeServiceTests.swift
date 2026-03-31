import Testing
import Foundation
import SwiftData
@testable import FocusCore

// MARK: - FocusModeService Tests

/// Unit tests for FocusModeService covering CRUD operations and validation.
/// Validates VAL-FOCUS-001, VAL-FOCUS-002, and VAL-FOCUS-010.
@Suite("FocusModeService Tests", .serialized)
struct FocusModeServiceTests {

    // MARK: - Test Helpers

    /// Creates an in-memory ModelContainer with all required model types.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaV2.models)
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

    /// Creates a FocusModeService with fresh dependencies.
    @MainActor
    private func makeService() throws -> (FocusModeService, MockShieldService, MockMonitoringService, ModelContext) {
        let container = try makeContainer()
        let context = ModelContext(container)
        let shieldService = MockShieldService()
        let monitoringService = MockMonitoringService()
        let service = FocusModeService(
            modelContext: context,
            shieldService: shieldService,
            monitoringService: monitoringService
        )
        return (service, shieldService, monitoringService, context)
    }

    // MARK: - Create Tests

    @Test("Create profile with valid name succeeds")
    @MainActor
    func testCreateProfileWithValidName() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        #expect(profile.name == "Work")
        #expect(profile.iconName == "moon.fill") // default icon
        #expect(profile.colorHex == "#4A90D9") // default color
        #expect(profile.isActive == false)

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.count == 1)
        #expect(allProfiles.first?.name == "Work")
    }

    @Test("Create profile with custom icon and color")
    @MainActor
    func testCreateProfileWithCustomValues() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(
            name: "Evening",
            iconName: "sun.max.fill",
            colorHex: "#E74C3C"
        )

        #expect(profile.name == "Evening")
        #expect(profile.iconName == "sun.max.fill")
        #expect(profile.colorHex == "#E74C3C")
    }

    @Test("Create profile with default icon and color when not specified")
    @MainActor
    func testCreateProfileDefaults() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Morning")

        #expect(profile.iconName == "moon.fill")
        #expect(profile.colorHex == "#4A90D9")
    }

    @Test("Create profile with empty name throws emptyName error")
    @MainActor
    func testCreateProfileEmptyName() throws {
        let (service, _, _, _) = try makeService()

        #expect(throws: FocusModeServiceError.emptyName) {
            try service.createProfile(name: "")
        }

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.isEmpty)
    }

    @Test("Create profile with whitespace-only name throws emptyName error")
    @MainActor
    func testCreateProfileWhitespaceName() throws {
        let (service, _, _, _) = try makeService()

        #expect(throws: FocusModeServiceError.emptyName) {
            try service.createProfile(name: "   \t\n  ")
        }

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.isEmpty)
    }

    @Test("Create profile with duplicate name throws duplicateName error")
    @MainActor
    func testCreateProfileDuplicateName() throws {
        let (service, _, _, _) = try makeService()

        try service.createProfile(name: "Work")

        #expect(throws: FocusModeServiceError.duplicateName("Work")) {
            try service.createProfile(name: "Work")
        }

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.count == 1)
    }

    @Test("Create profile with case-insensitive duplicate name throws duplicateName error")
    @MainActor
    func testCreateProfileCaseInsensitiveDuplicate() throws {
        let (service, _, _, _) = try makeService()

        try service.createProfile(name: "Work")

        #expect(throws: FocusModeServiceError.duplicateName("work")) {
            try service.createProfile(name: "work")
        }

        #expect(throws: FocusModeServiceError.duplicateName("WORK")) {
            try service.createProfile(name: "WORK")
        }

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.count == 1)
    }

    @Test("Create profile trims whitespace from name")
    @MainActor
    func testCreateProfileTrimsWhitespace() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "  Work  ")

        #expect(profile.name == "Work")
    }

    @Test("Create multiple profiles persists all and sorted by createdAt")
    @MainActor
    func testCreateMultipleProfiles() throws {
        let (service, _, _, _) = try makeService()

        try service.createProfile(name: "Work")
        try service.createProfile(name: "Evening")
        try service.createProfile(name: "Morning")

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.count == 3)
        #expect(allProfiles[0].name == "Work")
        #expect(allProfiles[1].name == "Evening")
        #expect(allProfiles[2].name == "Morning")
    }

    // MARK: - Update Tests

    @Test("Update profile name, icon, and color persists changes")
    @MainActor
    func testUpdateProfile() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")
        let profileId = profile.id

        try service.updateProfile(
            id: profileId,
            name: "Study",
            iconName: "book.fill",
            colorHex: "#2ECC71"
        )

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.count == 1)
        #expect(allProfiles.first?.name == "Study")
        #expect(allProfiles.first?.iconName == "book.fill")
        #expect(allProfiles.first?.colorHex == "#2ECC71")
    }

    @Test("Update profile with empty name throws emptyName error")
    @MainActor
    func testUpdateProfileEmptyName() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        #expect(throws: FocusModeServiceError.emptyName) {
            try service.updateProfile(id: profile.id, name: "", iconName: "moon.fill", colorHex: "#4A90D9")
        }

        // Verify original name preserved
        let allProfiles = try service.fetchAll()
        #expect(allProfiles.first?.name == "Work")
    }

    @Test("Update profile to duplicate name of another profile throws error")
    @MainActor
    func testUpdateProfileDuplicateName() throws {
        let (service, _, _, _) = try makeService()

        try service.createProfile(name: "Work")
        let evening = try service.createProfile(name: "Evening")

        #expect(throws: FocusModeServiceError.duplicateName("Work")) {
            try service.updateProfile(id: evening.id, name: "Work", iconName: "moon.fill", colorHex: "#4A90D9")
        }
    }

    @Test("Update profile to same name as itself succeeds")
    @MainActor
    func testUpdateProfileSameNameSucceeds() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        // Updating to the same name but different icon/color should succeed
        try service.updateProfile(
            id: profile.id,
            name: "Work",
            iconName: "star.fill",
            colorHex: "#E74C3C"
        )

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.first?.iconName == "star.fill")
        #expect(allProfiles.first?.colorHex == "#E74C3C")
    }

    @Test("Update non-existent profile throws profileNotFound error")
    @MainActor
    func testUpdateNonExistentProfile() throws {
        let (service, _, _, _) = try makeService()

        let fakeId = UUID()
        #expect(throws: FocusModeServiceError.profileNotFound(fakeId)) {
            try service.updateProfile(id: fakeId, name: "Work", iconName: "moon.fill", colorHex: "#4A90D9")
        }
    }

    // MARK: - Delete Tests

    @Test("Delete profile removes from store")
    @MainActor
    func testDeleteProfile() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")
        let profileId = profile.id

        try service.deleteProfile(id: profileId)

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.isEmpty)
    }

    @Test("Delete profile clears associated shield store")
    @MainActor
    func testDeleteProfileClearsShields() throws {
        let (service, shieldService, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")
        let storeName = profile.id.uuidString

        // Simulate an active shield store
        shieldService.applyShields(
            storeName: storeName,
            applications: [Data([1, 2, 3])],
            categories: nil,
            webDomains: nil
        )
        #expect(shieldService.isShielding(storeName: storeName) == true)

        try service.deleteProfile(id: profile.id)

        // Shield store should be cleared
        #expect(shieldService.clearShieldsCalls.contains(storeName))
        #expect(shieldService.isShielding(storeName: storeName) == false)
    }

    @Test("Delete profile stops associated monitoring")
    @MainActor
    func testDeleteProfileStopsMonitoring() throws {
        let (service, _, monitoringService, _) = try makeService()

        let profile = try service.createProfile(name: "Work")
        let activityName = "focus_\(profile.id.uuidString)"

        // Simulate active monitoring
        try monitoringService.startMonitoring(
            activityName: activityName,
            schedule: ScheduleConfig(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        )
        #expect(monitoringService.activeMonitors.contains(activityName))

        try service.deleteProfile(id: profile.id)

        // Monitoring should be stopped using consistent focus_<uuid> naming
        #expect(monitoringService.stopMonitoringCalls.count == 1)
        #expect(monitoringService.stopMonitoringCalls.first == [activityName])
    }

    @Test("Delete non-existent profile throws profileNotFound error")
    @MainActor
    func testDeleteNonExistentProfile() throws {
        let (service, _, _, _) = try makeService()

        let fakeId = UUID()
        #expect(throws: FocusModeServiceError.profileNotFound(fakeId)) {
            try service.deleteProfile(id: fakeId)
        }
    }

    @Test("Delete all profiles returns to empty state")
    @MainActor
    func testDeleteAllProfiles() throws {
        let (service, _, _, _) = try makeService()

        let p1 = try service.createProfile(name: "Work")
        let p2 = try service.createProfile(name: "Evening")

        try service.deleteProfile(id: p1.id)
        try service.deleteProfile(id: p2.id)

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.isEmpty)
    }

    // MARK: - Fetch Tests

    @Test("fetchAll returns empty array when no profiles exist")
    @MainActor
    func testFetchAllEmpty() throws {
        let (service, _, _, _) = try makeService()

        let allProfiles = try service.fetchAll()
        #expect(allProfiles.isEmpty)
    }

    @Test("fetchActive returns only active profiles")
    @MainActor
    func testFetchActive() throws {
        let (service, _, _, context) = try makeService()

        let work = try service.createProfile(name: "Work")
        try service.createProfile(name: "Evening")
        let morning = try service.createProfile(name: "Morning")

        // Manually set isActive for testing (activation service not in scope)
        work.isActive = true
        morning.isActive = true
        try context.save()

        let activeProfiles = try service.fetchActive()
        #expect(activeProfiles.count == 2)
        let names = activeProfiles.map(\.name)
        #expect(names.contains("Work"))
        #expect(names.contains("Morning"))
    }

    @Test("fetchActive returns empty when no active profiles")
    @MainActor
    func testFetchActiveEmpty() throws {
        let (service, _, _, _) = try makeService()

        try service.createProfile(name: "Work")

        let activeProfiles = try service.fetchActive()
        #expect(activeProfiles.isEmpty)
    }

    // MARK: - Error Equatable Tests

    @Test("FocusModeServiceError has descriptive messages")
    func testErrorDescriptions() {
        let emptyNameError = FocusModeServiceError.emptyName
        #expect(emptyNameError.localizedDescription == "Profile name cannot be empty")

        let duplicateError = FocusModeServiceError.duplicateName("Work")
        #expect(duplicateError.localizedDescription == "A profile named 'Work' already exists")

        let notFoundId = UUID()
        let notFoundError = FocusModeServiceError.profileNotFound(notFoundId)
        #expect(notFoundError.localizedDescription == "Profile with ID \(notFoundId) not found")
    }
}
