import Testing
import SwiftData
import Foundation
@testable import FocusCore

// MARK: - Helper

/// Creates an in-memory ModelContainer with all app models.
private func makeTestContainer() throws -> ModelContainer {
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

// MARK: - FocusMode CRUD Tests

@Suite("FocusMode CRUD Tests")
struct FocusModeCRUDTests {

    @Test("Create FocusMode with default values")
    func createWithDefaults() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Work")
        context.insert(mode)
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Work")
        #expect(fetched.first?.iconName == "moon.fill")
        #expect(fetched.first?.colorHex == "#4A90D9")
        #expect(fetched.first?.isActive == false)
        #expect(fetched.first?.scheduleDays.isEmpty == true)
        #expect(fetched.first?.serializedAppTokens == nil)
        #expect(fetched.first?.serializedCategoryTokens == nil)
        #expect(fetched.first?.serializedWebDomainTokens == nil)
    }

    @Test("Create FocusMode with custom values")
    func createWithCustomValues() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let tokenData = Data([0x01, 0x02, 0x03])
        let mode = FocusMode(
            name: "Evening",
            iconName: "moon.stars",
            colorHex: "#FF5733",
            scheduleDays: [2, 3, 4, 5, 6],
            scheduleStartHour: 18,
            scheduleStartMinute: 30,
            scheduleEndHour: 22,
            scheduleEndMinute: 0,
            serializedAppTokens: tokenData,
            isActive: true
        )
        context.insert(mode)
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let result = try #require(fetched.first)
        #expect(result.name == "Evening")
        #expect(result.iconName == "moon.stars")
        #expect(result.colorHex == "#FF5733")
        #expect(result.scheduleDays == [2, 3, 4, 5, 6])
        #expect(result.scheduleStartHour == 18)
        #expect(result.scheduleStartMinute == 30)
        #expect(result.scheduleEndHour == 22)
        #expect(result.scheduleEndMinute == 0)
        #expect(result.serializedAppTokens == tokenData)
        #expect(result.isActive == true)
    }

    @Test("Update FocusMode properties")
    func updateProperties() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Work")
        context.insert(mode)
        try context.save()

        // Update
        mode.name = "Deep Work"
        mode.iconName = "brain.head.profile"
        mode.isActive = true
        mode.scheduleDays = [2, 3, 4, 5, 6]
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let result = try #require(fetched.first)
        #expect(result.name == "Deep Work")
        #expect(result.iconName == "brain.head.profile")
        #expect(result.isActive == true)
        #expect(result.scheduleDays == [2, 3, 4, 5, 6])
    }

    @Test("Delete FocusMode")
    func deleteFocusMode() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Temporary")
        context.insert(mode)
        try context.save()

        let beforeDescriptor = FetchDescriptor<FocusMode>()
        let before = try context.fetch(beforeDescriptor)
        #expect(before.count == 1)

        context.delete(mode)
        try context.save()

        let afterDescriptor = FetchDescriptor<FocusMode>()
        let after = try context.fetch(afterDescriptor)
        #expect(after.count == 0)
    }

    @Test("Fetch FocusMode by name using predicate")
    func fetchByNamePredicate() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let work = FocusMode(name: "Work")
        let study = FocusMode(name: "Study")
        let evening = FocusMode(name: "Evening")
        context.insert(work)
        context.insert(study)
        context.insert(evening)
        try context.save()

        let targetName = "Study"
        let descriptor = FetchDescriptor<FocusMode>(
            predicate: #Predicate { $0.name == targetName }
        )
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.name == "Study")
    }

    @Test("Fetch active FocusModes using predicate")
    func fetchActiveModes() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let active1 = FocusMode(name: "Work", isActive: true)
        let inactive = FocusMode(name: "Study", isActive: false)
        let active2 = FocusMode(name: "Evening", isActive: true)
        context.insert(active1)
        context.insert(inactive)
        context.insert(active2)
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>(
            predicate: #Predicate { $0.isActive == true }
        )
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        let names = Set(results.map(\.name))
        #expect(names.contains("Work"))
        #expect(names.contains("Evening"))
    }
}

// MARK: - DeepFocusSession CRUD Tests

@Suite("DeepFocusSession CRUD Tests")
struct DeepFocusSessionCRUDTests {

    @Test("Create DeepFocusSession with defaults")
    func createWithDefaults() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let session = DeepFocusSession()
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let result = try #require(fetched.first)
        #expect(result.configuredDuration == 1800)
        #expect(result.remainingSeconds == 1800)
        #expect(result.status == .idle)
        #expect(result.bypassCount == 0)
        #expect(result.breakCount == 0)
        #expect(result.totalBreakDuration == 0)
        #expect(result.serializedAllowedTokens == nil)
        #expect(result.focusMode == nil)
    }

    @Test("Create DeepFocusSession with custom values")
    func createWithCustomValues() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let session = DeepFocusSession(
            configuredDuration: 3600,
            remainingSeconds: 2400,
            status: .active,
            bypassCount: 2,
            breakCount: 1,
            totalBreakDuration: 300
        )
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.configuredDuration == 3600)
        #expect(result.remainingSeconds == 2400)
        #expect(result.status == .active)
        #expect(result.bypassCount == 2)
        #expect(result.breakCount == 1)
        #expect(result.totalBreakDuration == 300)
    }

    @Test("Update DeepFocusSession status progression")
    func updateStatusProgression() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let session = DeepFocusSession(status: .idle)
        context.insert(session)
        try context.save()

        // Progress through states
        session.status = .active
        session.remainingSeconds = 1500
        try context.save()

        session.status = .onBreak
        session.breakCount = 1
        try context.save()

        session.status = .active
        try context.save()

        session.status = .completed
        session.remainingSeconds = 0
        try context.save()

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.status == .completed)
        #expect(result.remainingSeconds == 0)
        #expect(result.breakCount == 1)
    }

    @Test("Delete DeepFocusSession")
    func deleteSession() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let session = DeepFocusSession()
        context.insert(session)
        try context.save()

        context.delete(session)
        try context.save()

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 0)
    }
}

// MARK: - ScreenTimeEntry CRUD Tests

@Suite("ScreenTimeEntry CRUD Tests")
struct ScreenTimeEntryCRUDTests {

    @Test("Create and fetch ScreenTimeEntry")
    func createAndFetch() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let entry = ScreenTimeEntry(
            date: Date(),
            appIdentifier: "com.example.app",
            categoryName: "Social",
            duration: 3600,
            sessionID: UUID()
        )
        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<ScreenTimeEntry>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.appIdentifier == "com.example.app")
        #expect(result.categoryName == "Social")
        #expect(result.duration == 3600)
        #expect(result.sessionID != nil)
    }

    @Test("Fetch ScreenTimeEntries by date range")
    func fetchByDateRange() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let entry1 = ScreenTimeEntry(date: today, duration: 100)
        let entry2 = ScreenTimeEntry(date: yesterday, duration: 200)
        let entry3 = ScreenTimeEntry(date: twoDaysAgo, duration: 300)
        let entry4 = ScreenTimeEntry(date: threeDaysAgo, duration: 400)
        context.insert(entry1)
        context.insert(entry2)
        context.insert(entry3)
        context.insert(entry4)
        try context.save()

        // Fetch entries from yesterday onward
        let rangeStart = yesterday
        let descriptor = FetchDescriptor<ScreenTimeEntry>(
            predicate: #Predicate { $0.date >= rangeStart }
        )
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        let durations = Set(results.map(\.duration))
        #expect(durations.contains(100))
        #expect(durations.contains(200))
    }

    @Test("Update ScreenTimeEntry duration")
    func updateDuration() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let entry = ScreenTimeEntry(date: Date(), duration: 100)
        context.insert(entry)
        try context.save()

        entry.duration = 500
        try context.save()

        let descriptor = FetchDescriptor<ScreenTimeEntry>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.first?.duration == 500)
    }

    @Test("Delete ScreenTimeEntry")
    func deleteEntry() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let entry = ScreenTimeEntry(date: Date(), duration: 100)
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let descriptor = FetchDescriptor<ScreenTimeEntry>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 0)
    }
}

// MARK: - BlockedAppGroup CRUD Tests

@Suite("BlockedAppGroup CRUD Tests")
struct BlockedAppGroupCRUDTests {

    @Test("Create and fetch BlockedAppGroup")
    func createAndFetch() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let tokenData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let group = BlockedAppGroup(name: "Social Media", serializedAppTokens: tokenData)
        context.insert(group)
        try context.save()

        let descriptor = FetchDescriptor<BlockedAppGroup>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.name == "Social Media")
        #expect(result.serializedAppTokens == tokenData)
    }

    @Test("Update BlockedAppGroup name and tokens")
    func updateNameAndTokens() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let group = BlockedAppGroup(name: "Games")
        context.insert(group)
        try context.save()

        let newTokens = Data([0x01, 0x02])
        group.name = "Gaming Apps"
        group.serializedAppTokens = newTokens
        try context.save()

        let descriptor = FetchDescriptor<BlockedAppGroup>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.name == "Gaming Apps")
        #expect(result.serializedAppTokens == newTokens)
    }

    @Test("Delete BlockedAppGroup")
    func deleteGroup() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let group = BlockedAppGroup(name: "Temp")
        context.insert(group)
        try context.save()

        context.delete(group)
        try context.save()

        let descriptor = FetchDescriptor<BlockedAppGroup>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 0)
    }
}

// MARK: - Relationship Tests

@Suite("Relationship Tests")
struct RelationshipTests {

    @Test("DeepFocusSession references FocusMode")
    func sessionReferencesFocusMode() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Work")
        context.insert(mode)

        let session = DeepFocusSession(
            configuredDuration: 3600,
            status: .active,
            focusMode: mode
        )
        context.insert(session)
        try context.save()

        let sessionDescriptor = FetchDescriptor<DeepFocusSession>()
        let fetchedSessions = try context.fetch(sessionDescriptor)
        let fetchedSession = try #require(fetchedSessions.first)

        #expect(fetchedSession.focusMode?.name == "Work")
        #expect(fetchedSession.focusMode?.id == mode.id)
    }

    @Test("FocusMode has inverse sessions relationship")
    func focusModeHasSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Study")
        context.insert(mode)

        let session1 = DeepFocusSession(status: .completed, focusMode: mode)
        let session2 = DeepFocusSession(status: .active, focusMode: mode)
        context.insert(session1)
        context.insert(session2)
        try context.save()

        let modeDescriptor = FetchDescriptor<FocusMode>()
        let fetchedModes = try context.fetch(modeDescriptor)
        let fetchedMode = try #require(fetchedModes.first)

        #expect(fetchedMode.sessions.count == 2)
    }

    @Test("Deleting FocusMode nullifies session relationship")
    func deleteFocusModeNullifiesSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Work")
        context.insert(mode)

        let session = DeepFocusSession(status: .completed, focusMode: mode)
        context.insert(session)
        try context.save()

        // Delete the focus mode
        context.delete(mode)
        try context.save()

        // Session should still exist but with nil focusMode
        let sessionDescriptor = FetchDescriptor<DeepFocusSession>()
        let fetchedSessions = try context.fetch(sessionDescriptor)
        #expect(fetchedSessions.count == 1)
        #expect(fetchedSessions.first?.focusMode == nil)

        // FocusMode should be gone
        let modeDescriptor = FetchDescriptor<FocusMode>()
        let fetchedModes = try context.fetch(modeDescriptor)
        #expect(fetchedModes.count == 0)
    }
}

// MARK: - Multiple Model Coexistence Tests

@Suite("Multiple Model Coexistence Tests")
struct MultipleModelCoexistenceTests {

    @Test("All four models coexist in one container")
    func allModelsCoexist() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        // Insert one of each
        let mode = FocusMode(name: "Work")
        let session = DeepFocusSession(status: .active, focusMode: mode)
        let entry = ScreenTimeEntry(date: Date(), duration: 3600)
        let group = BlockedAppGroup(name: "Social")

        context.insert(mode)
        context.insert(session)
        context.insert(entry)
        context.insert(group)
        try context.save()

        // Fetch each type
        let modes = try context.fetch(FetchDescriptor<FocusMode>())
        let sessions = try context.fetch(FetchDescriptor<DeepFocusSession>())
        let entries = try context.fetch(FetchDescriptor<ScreenTimeEntry>())
        let groups = try context.fetch(FetchDescriptor<BlockedAppGroup>())

        #expect(modes.count == 1)
        #expect(sessions.count == 1)
        #expect(entries.count == 1)
        #expect(groups.count == 1)
    }

    @Test("Deleting one model type does not affect others")
    func deletionIsolation() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "Work")
        let entry = ScreenTimeEntry(date: Date(), duration: 100)
        let group = BlockedAppGroup(name: "Games")
        context.insert(mode)
        context.insert(entry)
        context.insert(group)
        try context.save()

        // Delete only the entry
        context.delete(entry)
        try context.save()

        let modes = try context.fetch(FetchDescriptor<FocusMode>())
        let entries = try context.fetch(FetchDescriptor<ScreenTimeEntry>())
        let groups = try context.fetch(FetchDescriptor<BlockedAppGroup>())

        #expect(modes.count == 1)
        #expect(entries.count == 0)
        #expect(groups.count == 1)
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Case Tests")
struct EdgeCaseTests {

    @Test("Empty state - no models persisted")
    func emptyState() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let modes = try context.fetch(FetchDescriptor<FocusMode>())
        let sessions = try context.fetch(FetchDescriptor<DeepFocusSession>())
        let entries = try context.fetch(FetchDescriptor<ScreenTimeEntry>())
        let groups = try context.fetch(FetchDescriptor<BlockedAppGroup>())

        #expect(modes.isEmpty)
        #expect(sessions.isEmpty)
        #expect(entries.isEmpty)
        #expect(groups.isEmpty)
    }

    @Test("Very long name is stored correctly")
    func veryLongName() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let longName = String(repeating: "A", count: 10_000)
        let mode = FocusMode(name: longName)
        context.insert(mode)
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.name == longName)
        #expect(result.name.count == 10_000)
    }

    @Test("Duplicate names are stored independently")
    func duplicateNames() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode1 = FocusMode(name: "Work")
        let mode2 = FocusMode(name: "Work")
        context.insert(mode1)
        context.insert(mode2)
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 2)
        // Both have the same name but different UUIDs
        #expect(fetched[0].name == "Work")
        #expect(fetched[1].name == "Work")
        #expect(fetched[0].id != fetched[1].id)
    }

    @Test("SessionStatus enum raw values are persisted correctly")
    func sessionStatusPersistence() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        for status in SessionStatus.allCases {
            let session = DeepFocusSession(status: status)
            context.insert(session)
        }
        try context.save()

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == SessionStatus.allCases.count)
        let statuses = Set(fetched.map(\.status))
        for expected in SessionStatus.allCases {
            #expect(statuses.contains(expected))
        }
    }

    @Test("FocusMode with empty scheduleDays array")
    func emptyScheduleDays() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let mode = FocusMode(name: "No Schedule", scheduleDays: [])
        context.insert(mode)
        try context.save()

        let descriptor = FetchDescriptor<FocusMode>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.scheduleDays.isEmpty)
    }

    @Test("ScreenTimeEntry with nil optional fields")
    func nilOptionalFields() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let entry = ScreenTimeEntry(
            date: Date(),
            appIdentifier: nil,
            categoryName: nil,
            duration: 0,
            sessionID: nil
        )
        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<ScreenTimeEntry>()
        let fetched = try context.fetch(descriptor)
        let result = try #require(fetched.first)

        #expect(result.appIdentifier == nil)
        #expect(result.categoryName == nil)
        #expect(result.duration == 0)
        #expect(result.sessionID == nil)
    }
}

// MARK: - VersionedSchema Tests

@Suite("VersionedSchema Tests")
struct VersionedSchemaTests {

    @Test("AppSchemaV1 has correct version identifier")
    func versionIdentifier() {
        #expect(AppSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test("AppSchemaV1 lists all four model types")
    func modelsList() {
        let models = AppSchemaV1.models
        #expect(models.count == 4)
    }

    @Test("ModelContainer initializes with migration plan")
    func containerWithMigrationPlan() throws {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [config]
        )
        // Container should be usable
        let context = ModelContext(container)
        let modes = try context.fetch(FetchDescriptor<FocusMode>())
        #expect(modes.isEmpty)
    }

    @Test("AppMigrationPlan has correct schemas list")
    func migrationPlanSchemas() {
        let schemas = AppMigrationPlan.schemas
        #expect(schemas.count == 1)
    }
}
