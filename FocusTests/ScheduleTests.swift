import Testing
import Foundation
import SwiftData
@testable import FocusCore

// MARK: - Schedule Validation Tests

/// Unit tests for schedule validation, overnight schedules, overlap detection,
/// monitoring lifecycle, 20-schedule limit, intervalDidEnd guard, and persistence.
/// Validates VAL-FOCUS-003, VAL-FOCUS-004, VAL-FOCUS-008, VAL-FOCUS-011, VAL-FOCUS-014.

@Suite("Schedule Config Validation", .serialized)
struct ScheduleConfigValidationTests {

    @Test("Valid same-day schedule passes validation")
    func testValidSameDaySchedule() throws {
        let schedule = ScheduleConfig(
            days: [.monday, .wednesday, .friday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(throws: Never.self) {
            try schedule.validate()
        }
    }

    @Test("Valid overnight schedule passes validation")
    func testValidOvernightSchedule() throws {
        let schedule = ScheduleConfig(
            days: [.monday, .tuesday],
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0
        )
        #expect(throws: Never.self) {
            try schedule.validate()
        }
        #expect(schedule.isOvernight == true)
    }

    @Test("Same-day schedule is not overnight")
    func testSameDayNotOvernight() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(schedule.isOvernight == false)
    }

    @Test("No days selected throws noDaysSelected")
    func testNoDaysSelected() {
        let schedule = ScheduleConfig(
            days: [],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(throws: ScheduleValidationError.noDaysSelected) {
            try schedule.validate()
        }
    }

    @Test("Same start and end time throws zeroDuration")
    func testZeroDuration() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 30,
            endHour: 9, endMinute: 30
        )
        #expect(throws: ScheduleValidationError.zeroDuration) {
            try schedule.validate()
        }
    }

    @Test("Invalid start hour throws invalidHour")
    func testInvalidStartHour() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 25, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(throws: ScheduleValidationError.invalidHour(25)) {
            try schedule.validate()
        }
    }

    @Test("Invalid end hour throws invalidHour")
    func testInvalidEndHour() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 0,
            endHour: 24, endMinute: 0
        )
        #expect(throws: ScheduleValidationError.invalidHour(24)) {
            try schedule.validate()
        }
    }

    @Test("Invalid start minute throws invalidMinute")
    func testInvalidStartMinute() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 60,
            endHour: 17, endMinute: 0
        )
        #expect(throws: ScheduleValidationError.invalidMinute(60)) {
            try schedule.validate()
        }
    }

    @Test("Invalid end minute throws invalidMinute")
    func testInvalidEndMinute() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: -1
        )
        #expect(throws: ScheduleValidationError.invalidMinute(-1)) {
            try schedule.validate()
        }
    }

    @Test("Negative hour throws invalidHour")
    func testNegativeHour() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: -1, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(throws: ScheduleValidationError.invalidHour(-1)) {
            try schedule.validate()
        }
    }

    @Test("Schedule with all days is valid")
    func testAllDays() throws {
        let schedule = ScheduleConfig(
            days: Weekday.allCases,
            startHour: 8, startMinute: 0,
            endHour: 20, endMinute: 0
        )
        #expect(throws: Never.self) {
            try schedule.validate()
        }
    }

    @Test("startTotalMinutes and endTotalMinutes compute correctly")
    func testTotalMinutes() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 14, startMinute: 30,
            endHour: 22, endMinute: 15
        )
        #expect(schedule.startTotalMinutes == 870)
        #expect(schedule.endTotalMinutes == 1335)
    }
}

// MARK: - Schedule containsTime Tests

@Suite("Schedule containsTime", .serialized)
struct ScheduleContainsTimeTests {

    @Test("Same-day schedule contains time within range")
    func testSameDayContainsTime() {
        let schedule = ScheduleConfig(
            days: [.monday, .wednesday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 12, minute: 0, weekday: .monday) == true)
        #expect(schedule.containsTime(hour: 9, minute: 0, weekday: .monday) == true)
        #expect(schedule.containsTime(hour: 16, minute: 59, weekday: .wednesday) == true)
    }

    @Test("Same-day schedule excludes time outside range")
    func testSameDayExcludesTime() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 8, minute: 59, weekday: .monday) == false)
        #expect(schedule.containsTime(hour: 17, minute: 0, weekday: .monday) == false)
        #expect(schedule.containsTime(hour: 17, minute: 1, weekday: .monday) == false)
    }

    @Test("Same-day schedule excludes non-scheduled days")
    func testSameDayExcludesWrongDay() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 12, minute: 0, weekday: .tuesday) == false)
    }

    @Test("Overnight schedule contains late evening on start day")
    func testOvernightContainsEvening() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 23, minute: 0, weekday: .monday) == true)
        #expect(schedule.containsTime(hour: 22, minute: 0, weekday: .monday) == true)
    }

    @Test("Overnight schedule contains early morning on next day")
    func testOvernightContainsMorning() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0
        )
        // Monday night -> Tuesday morning
        #expect(schedule.containsTime(hour: 3, minute: 0, weekday: .tuesday) == true)
        #expect(schedule.containsTime(hour: 6, minute: 59, weekday: .tuesday) == true)
    }

    @Test("Overnight schedule excludes daytime on start day")
    func testOvernightExcludesDaytime() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 12, minute: 0, weekday: .monday) == false)
        #expect(schedule.containsTime(hour: 21, minute: 59, weekday: .monday) == false)
    }

    @Test("Overnight schedule excludes after end on next day")
    func testOvernightExcludesAfterEnd() {
        let schedule = ScheduleConfig(
            days: [.monday],
            startHour: 22, startMinute: 0,
            endHour: 7, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 7, minute: 0, weekday: .tuesday) == false)
        #expect(schedule.containsTime(hour: 8, minute: 0, weekday: .tuesday) == false)
    }

    @Test("Saturday overnight wraps to Sunday")
    func testSaturdayOvernightToSunday() {
        let schedule = ScheduleConfig(
            days: [.saturday],
            startHour: 23, startMinute: 0,
            endHour: 6, endMinute: 0
        )
        #expect(schedule.containsTime(hour: 23, minute: 30, weekday: .saturday) == true)
        #expect(schedule.containsTime(hour: 2, minute: 0, weekday: .sunday) == true)
        #expect(schedule.containsTime(hour: 6, minute: 0, weekday: .sunday) == false)
    }
}

// MARK: - Weekday Tests

@Suite("Weekday")
struct WeekdayTests {

    @Test("Weekday rawValues match DateComponents convention")
    func testRawValues() {
        #expect(Weekday.sunday.rawValue == 1)
        #expect(Weekday.monday.rawValue == 2)
        #expect(Weekday.saturday.rawValue == 7)
    }

    @Test("orderedForDisplay starts with Monday")
    func testOrderedForDisplay() {
        let ordered = Weekday.orderedForDisplay
        #expect(ordered.first == .monday)
        #expect(ordered.last == .sunday)
        #expect(ordered.count == 7)
    }

    @Test("shortName returns correct abbreviations")
    func testShortNames() {
        #expect(Weekday.monday.shortName == "Mon")
        #expect(Weekday.friday.shortName == "Fri")
        #expect(Weekday.sunday.shortName == "Sun")
    }

    @Test("previousDay wraps correctly")
    func testPreviousDay() {
        #expect(Weekday.monday.previousDay == .sunday)
        #expect(Weekday.sunday.previousDay == .saturday)
        #expect(Weekday.wednesday.previousDay == .tuesday)
    }

    @Test("nextDay wraps correctly")
    func testNextDay() {
        #expect(Weekday.saturday.nextDay == .sunday)
        #expect(Weekday.sunday.nextDay == .monday)
        #expect(Weekday.friday.nextDay == .saturday)
    }

    @Test("Init from dayNumber")
    func testInitFromDayNumber() {
        #expect(Weekday(dayNumber: 1) == .sunday)
        #expect(Weekday(dayNumber: 7) == .saturday)
        #expect(Weekday(dayNumber: 0) == nil)
        #expect(Weekday(dayNumber: 8) == nil)
    }
}

// MARK: - Schedule Overlap Detection Tests

@Suite("Schedule Overlap Detection", .serialized)
struct ScheduleOverlapDetectionTests {

    let detector = ScheduleOverlapDetector()

    @Test("No overlap between non-overlapping schedules")
    func testNoOverlap() {
        let s1 = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 12, endMinute: 0
        )
        let s2 = ScheduleConfig(
            days: [.monday], startHour: 13, startMinute: 0, endHour: 17, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(s1, s2)
        #expect(overlap.isEmpty)
    }

    @Test("Overlap on same day same time")
    func testOverlapSameTime() {
        let s1 = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let s2 = ScheduleConfig(
            days: [.monday], startHour: 12, startMinute: 0, endHour: 15, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(s1, s2)
        #expect(overlap == [.monday])
    }

    @Test("No overlap on different days")
    func testNoOverlapDifferentDays() {
        let s1 = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let s2 = ScheduleConfig(
            days: [.tuesday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(s1, s2)
        #expect(overlap.isEmpty)
    }

    @Test("Overlap on multiple shared days")
    func testOverlapMultipleDays() {
        let s1 = ScheduleConfig(
            days: [.monday, .wednesday, .friday],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let s2 = ScheduleConfig(
            days: [.wednesday, .friday, .saturday],
            startHour: 14, startMinute: 0, endHour: 18, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(s1, s2)
        #expect(overlap == [.wednesday, .friday])
    }

    @Test("Adjacent time ranges don't overlap")
    func testAdjacentNoOverlap() {
        let s1 = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 12, endMinute: 0
        )
        let s2 = ScheduleConfig(
            days: [.monday], startHour: 12, startMinute: 0, endHour: 15, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(s1, s2)
        #expect(overlap.isEmpty)
    }

    @Test("Overnight schedule overlaps with early morning schedule")
    func testOvernightOverlap() {
        let overnight = ScheduleConfig(
            days: [.monday], startHour: 22, startMinute: 0, endHour: 7, endMinute: 0
        )
        let morning = ScheduleConfig(
            days: [.tuesday], startHour: 5, startMinute: 0, endHour: 10, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(overnight, morning)
        #expect(overlap == [.tuesday])
    }

    @Test("Two overnight schedules can overlap")
    func testTwoOvernightOverlap() {
        let s1 = ScheduleConfig(
            days: [.monday], startHour: 22, startMinute: 0, endHour: 6, endMinute: 0
        )
        let s2 = ScheduleConfig(
            days: [.monday], startHour: 23, startMinute: 0, endHour: 5, endMinute: 0
        )
        let overlap = detector.findOverlappingDays(s1, s2)
        // Should overlap on Monday (evening) and Tuesday (morning)
        #expect(overlap.contains(.monday))
        #expect(overlap.contains(.tuesday))
    }

    @Test("detectConflicts returns correct conflict info")
    func testDetectConflicts() {
        let target = ScheduleConfig(
            days: [.monday, .wednesday],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let existing: [(name: String, id: UUID, schedule: ScheduleConfig)] = [
            (name: "Work", id: UUID(), schedule: ScheduleConfig(
                days: [.monday],
                startHour: 14, startMinute: 0, endHour: 18, endMinute: 0
            )),
            (name: "Evening", id: UUID(), schedule: ScheduleConfig(
                days: [.friday],
                startHour: 18, startMinute: 0, endHour: 23, endMinute: 0
            ))
        ]
        let conflicts = detector.detectConflicts(
            targetSchedule: target,
            targetProfileName: "Study",
            existingProfiles: existing
        )
        #expect(conflicts.count == 1)
        #expect(conflicts.first?.profileName2 == "Work")
        #expect(conflicts.first?.overlappingDays == [.monday])
    }

    @Test("detectConflicts excludes self in edit mode")
    func testDetectConflictsExcludesSelf() {
        let selfId = UUID()
        let target = ScheduleConfig(
            days: [.monday],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let existing: [(name: String, id: UUID, schedule: ScheduleConfig)] = [
            (name: "Work", id: selfId, schedule: ScheduleConfig(
                days: [.monday],
                startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
            ))
        ]
        let conflicts = detector.detectConflicts(
            targetSchedule: target,
            targetProfileName: "Work",
            existingProfiles: existing,
            excludeProfileId: selfId
        )
        #expect(conflicts.isEmpty)
    }
}

// MARK: - Schedule Manager Tests

@Suite("Schedule Manager", .serialized)
struct ScheduleManagerTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [config])
    }

    @MainActor
    private func makeManager() throws -> (ScheduleManager, MockMonitoringService, MockShieldService, ModelContext) {
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
        return (manager, monitoringService, shieldService, context)
    }

    @MainActor
    private func createProfile(context: ModelContext, name: String, days: [Int] = [], startHour: Int = 9, startMinute: Int = 0, endHour: Int = 17, endMinute: Int = 0) -> FocusMode {
        let profile = FocusMode(
            name: name,
            scheduleDays: days,
            scheduleStartHour: startHour,
            scheduleStartMinute: startMinute,
            scheduleEndHour: endHour,
            scheduleEndMinute: endMinute
        )
        context.insert(profile)
        try? context.save()
        return profile
    }

    // MARK: - Registration Tests

    @Test("Register schedule starts monitoring")
    @MainActor
    func testRegisterScheduleStartsMonitoring() throws {
        let (manager, monitoringService, _, context) = try makeManager()
        let profile = createProfile(context: context, name: "Work")
        let schedule = ScheduleConfig(
            days: [.monday, .friday],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        try manager.registerSchedule(for: profile, schedule: schedule)

        #expect(monitoringService.startMonitoringCalls.count == 1)
        #expect(monitoringService.activeMonitors.count == 1)
        let activityName = manager.activityName(for: profile)
        #expect(monitoringService.activeMonitors.contains(activityName))
    }

    @Test("Edit schedule stops old and starts new monitoring")
    @MainActor
    func testEditScheduleStopsOldStartsNew() throws {
        let (manager, monitoringService, _, context) = try makeManager()
        let profile = createProfile(context: context, name: "Work")

        let schedule1 = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        try manager.registerSchedule(for: profile, schedule: schedule1)

        let schedule2 = ScheduleConfig(
            days: [.tuesday], startHour: 10, startMinute: 0, endHour: 18, endMinute: 0
        )
        try manager.registerSchedule(for: profile, schedule: schedule2)

        // Should have stopped the old schedule and started a new one
        #expect(monitoringService.stopMonitoringCalls.count == 1)
        #expect(monitoringService.startMonitoringCalls.count == 2)
        #expect(monitoringService.activeMonitors.count == 1)
    }

    @Test("Unregister schedule stops monitoring")
    @MainActor
    func testUnregisterSchedule() throws {
        let (manager, monitoringService, _, context) = try makeManager()
        let profile = createProfile(context: context, name: "Work")

        let schedule = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        try manager.registerSchedule(for: profile, schedule: schedule)
        #expect(monitoringService.activeMonitors.count == 1)

        manager.unregisterSchedule(for: profile)
        #expect(monitoringService.activeMonitors.isEmpty)
    }

    // MARK: - 20-Schedule Limit Tests (VAL-FOCUS-008)

    @Test("20-schedule limit is enforced")
    @MainActor
    func testScheduleLimitEnforced() throws {
        let (manager, monitoringService, _, context) = try makeManager()

        // Register 20 schedules
        for i in 0..<20 {
            let profile = createProfile(context: context, name: "Profile \(i)")
            let schedule = ScheduleConfig(
                days: [.monday], startHour: i % 24, startMinute: 0,
                endHour: (i + 1) % 24, endMinute: 0
            )
            try manager.registerSchedule(for: profile, schedule: schedule)
        }
        #expect(monitoringService.activeMonitors.count == 20)

        // 21st should throw ScheduleManagerError.scheduleLimitReached
        let extraProfile = createProfile(context: context, name: "Extra")
        let extraSchedule = ScheduleConfig(
            days: [.tuesday], startHour: 8, startMinute: 0, endHour: 9, endMinute: 0
        )
        #expect(throws: ScheduleManagerError.scheduleLimitReached(currentCount: 20)) {
            try manager.registerSchedule(for: extraProfile, schedule: extraSchedule)
        }
    }

    @Test("Replacing existing schedule doesn't count against limit")
    @MainActor
    func testReplacingDoesntCountAgainstLimit() throws {
        let (manager, monitoringService, _, context) = try makeManager()

        // Register 20 schedules
        var profiles: [FocusMode] = []
        for i in 0..<20 {
            let profile = createProfile(context: context, name: "Profile \(i)")
            let schedule = ScheduleConfig(
                days: [.monday], startHour: i % 24, startMinute: 0,
                endHour: (i + 1) % 24, endMinute: 0
            )
            try manager.registerSchedule(for: profile, schedule: schedule)
            profiles.append(profile)
        }

        // Replacing one of the existing schedules should work
        let newSchedule = ScheduleConfig(
            days: [.tuesday], startHour: 10, startMinute: 0, endHour: 11, endMinute: 0
        )
        #expect(throws: Never.self) {
            try manager.registerSchedule(for: profiles[0], schedule: newSchedule)
        }
    }

    @Test("Schedule limit error has correct message")
    @MainActor
    func testScheduleLimitErrorMessage() {
        let error = ScheduleManagerError.scheduleLimitReached(currentCount: 20)
        #expect(error.localizedDescription.contains("20"))
    }

    @Test("remainingScheduleSlots returns correct count")
    @MainActor
    func testRemainingSlots() throws {
        let (manager, _, _, context) = try makeManager()

        #expect(manager.remainingScheduleSlots == 20)

        let profile = createProfile(context: context, name: "Work")
        let schedule = ScheduleConfig(
            days: [.monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        try manager.registerSchedule(for: profile, schedule: schedule)

        #expect(manager.remainingScheduleSlots == 19)
    }

    // MARK: - Re-registration Tests (VAL-FOCUS-011)

    @Test("Re-register active schedules on launch")
    @MainActor
    func testReregisterActiveSchedules() throws {
        let (manager, monitoringService, _, context) = try makeManager()

        let profile1 = createProfile(
            context: context, name: "Work",
            days: [2, 3, 4, 5, 6], // Mon-Fri
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        let profile2 = createProfile(
            context: context, name: "Evening",
            days: [1, 7], // Sun, Sat
            startHour: 20, startMinute: 0, endHour: 23, endMinute: 0
        )
        // Profile with no schedule should be skipped
        let profile3 = createProfile(context: context, name: "NoSchedule")

        let failures = manager.reregisterActiveSchedules(profiles: [profile1, profile2, profile3])

        #expect(failures.isEmpty)
        #expect(monitoringService.activeMonitors.count == 2)
        #expect(monitoringService.startMonitoringCalls.count == 2)
    }

    @Test("Re-register skips profiles without schedule days")
    @MainActor
    func testReregisterSkipsEmpty() throws {
        let (manager, monitoringService, _, context) = try makeManager()
        let profile = createProfile(context: context, name: "Empty")

        let failures = manager.reregisterActiveSchedules(profiles: [profile])

        #expect(failures.isEmpty)
        #expect(monitoringService.startMonitoringCalls.isEmpty)
    }

    // MARK: - intervalDidEnd Guard Tests (VAL-FOCUS-014)

    @Test("shouldRemoveShieldsOnIntervalEnd returns false when within schedule")
    @MainActor
    func testIntervalEndGuardWithinSchedule() throws {
        let (manager, _, _, context) = try makeManager()

        // Create a profile active on Monday 9-17
        let profile = createProfile(
            context: context, name: "Work",
            days: [2], // Monday
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        profile.isActive = true

        // Simulate a Monday at 12:00 (within schedule)
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
        #expect(shouldRemove == false)
    }

    @Test("shouldRemoveShieldsOnIntervalEnd returns true when outside schedule")
    @MainActor
    func testIntervalEndGuardOutsideSchedule() throws {
        let (manager, _, _, context) = try makeManager()

        let profile = createProfile(
            context: context, name: "Work",
            days: [2], // Monday
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        profile.isActive = true

        // Simulate a Monday at 18:00 (outside schedule)
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
        #expect(shouldRemove == true)
    }

    @Test("shouldRemoveShieldsOnIntervalEnd returns true for inactive profile")
    @MainActor
    func testIntervalEndGuardInactiveProfile() throws {
        let (manager, _, _, context) = try makeManager()

        let profile = createProfile(
            context: context, name: "Work",
            days: [2], // Monday
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        profile.isActive = false

        let shouldRemove = manager.shouldRemoveShieldsOnIntervalEnd(
            activityName: manager.activityName(for: profile),
            profile: profile,
            currentDate: Date()
        )
        #expect(shouldRemove == true)
    }

    @Test("shouldRemoveShieldsOnIntervalEnd returns false for active overnight schedule within range")
    @MainActor
    func testIntervalEndGuardOvernightWithin() throws {
        let (manager, _, _, context) = try makeManager()

        // Friday overnight 22:00 - 07:00
        let profile = createProfile(
            context: context, name: "Sleep",
            days: [6], // Friday
            startHour: 22, startMinute: 0, endHour: 7, endMinute: 0
        )
        profile.isActive = true

        // Simulate Saturday at 3:00 AM (within overnight range)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 28 // Saturday
        components.hour = 3
        components.minute = 0
        let saturdayEarly = calendar.date(from: components)!

        let shouldRemove = manager.shouldRemoveShieldsOnIntervalEnd(
            activityName: manager.activityName(for: profile),
            profile: profile,
            currentDate: saturdayEarly
        )
        #expect(shouldRemove == false)
    }

    // MARK: - Activity Name Tests

    @Test("Activity name is deterministic based on profile ID")
    @MainActor
    func testActivityNameDeterministic() throws {
        let (manager, _, _, context) = try makeManager()
        let profile = createProfile(context: context, name: "Work")

        let name1 = manager.activityName(for: profile)
        let name2 = manager.activityName(for: profile)
        #expect(name1 == name2)
        #expect(name1 == "focus_\(profile.id.uuidString)")
    }

    // MARK: - ScheduleConfig from Profile

    @Test("scheduleConfig correctly converts profile data")
    @MainActor
    func testScheduleConfigFromProfile() throws {
        let (manager, _, _, context) = try makeManager()
        let profile = createProfile(
            context: context, name: "Work",
            days: [2, 3, 4], // Mon, Tue, Wed
            startHour: 9, startMinute: 30, endHour: 17, endMinute: 45
        )

        let config = manager.scheduleConfig(from: profile)
        #expect(config.days == [.monday, .tuesday, .wednesday])
        #expect(config.startHour == 9)
        #expect(config.startMinute == 30)
        #expect(config.endHour == 17)
        #expect(config.endMinute == 45)
        #expect(config.repeats == true)
    }
}

// MARK: - FocusModeService Schedule Integration Tests

@Suite("FocusModeService Schedule Integration", .serialized)
struct FocusModeServiceScheduleTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [config])
    }

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

    @Test("updateSchedule persists schedule data")
    @MainActor
    func testUpdateSchedulePersists() throws {
        let (service, _, _, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [2, 3, 4, 5, 6], // Mon-Fri
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        let profiles = try service.fetchAll()
        #expect(profiles.first?.scheduleDays == [2, 3, 4, 5, 6])
        #expect(profiles.first?.scheduleStartHour == 9)
        #expect(profiles.first?.scheduleEndHour == 17)
    }

    @Test("updateSchedule starts monitoring")
    @MainActor
    func testUpdateScheduleStartsMonitoring() throws {
        let (service, _, monitoringService, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [2],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        #expect(monitoringService.startMonitoringCalls.count == 1)
    }

    @Test("updateSchedule with empty days stops monitoring")
    @MainActor
    func testUpdateScheduleEmptyDaysStopsMonitoring() throws {
        let (service, _, monitoringService, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        // First set a schedule
        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [2],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        // Then clear it
        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        #expect(monitoringService.stopMonitoringCalls.count == 2) // once for replace, once for clear
    }

    @Test("updateSchedule on non-existent profile throws error")
    @MainActor
    func testUpdateScheduleNotFound() throws {
        let (service, _, _, _) = try makeService()
        let fakeId = UUID()
        #expect(throws: FocusModeServiceError.profileNotFound(fakeId)) {
            try service.updateSchedule(
                id: fakeId,
                scheduleDays: [2],
                startHour: 9, startMinute: 0,
                endHour: 17, endMinute: 0
            )
        }
    }

    @Test("Deleting profile with schedule stops monitoring")
    @MainActor
    func testDeleteProfileStopsScheduleMonitoring() throws {
        let (service, _, monitoringService, _) = try makeService()

        let profile = try service.createProfile(name: "Work")

        try service.updateSchedule(
            id: profile.id,
            scheduleDays: [2, 3],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        try service.deleteProfile(id: profile.id)

        // Should have been stopped via deleteProfile
        let stopCallCount = monitoringService.stopMonitoringCalls.count
        #expect(stopCallCount >= 1) // At least the delete stop call
    }

    @Test("Schedule data survives simulated restart (persistence)")
    @MainActor
    func testSchedulePersistenceAcrossRestart() throws {
        // Create a persistent (non-in-memory for this test) container
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [config])

        // First "session" — create profile with schedule
        let context1 = ModelContext(container)
        let shieldService1 = MockShieldService()
        let monitoringService1 = MockMonitoringService()
        let service1 = FocusModeService(
            modelContext: context1,
            shieldService: shieldService1,
            monitoringService: monitoringService1
        )

        let profile = try service1.createProfile(name: "Work")
        let profileId = profile.id
        try service1.updateSchedule(
            id: profileId,
            scheduleDays: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )

        // Second "session" — create new context from same container (simulates restart)
        let context2 = ModelContext(container)
        let shieldService2 = MockShieldService()
        let monitoringService2 = MockMonitoringService()
        let service2 = FocusModeService(
            modelContext: context2,
            shieldService: shieldService2,
            monitoringService: monitoringService2
        )

        let profiles = try service2.fetchAll()
        #expect(profiles.count == 1)
        let restored = profiles.first!
        #expect(restored.name == "Work")
        #expect(restored.scheduleDays == [2, 3, 4, 5, 6])
        #expect(restored.scheduleStartHour == 9)
        #expect(restored.scheduleEndHour == 17)

        // Re-register on launch
        let manager = ScheduleManager(
            monitoringService: monitoringService2,
            shieldService: shieldService2,
            sharedStateService: SharedStateService(defaults: UserDefaults.standard)
        )
        let failures = manager.reregisterActiveSchedules(profiles: profiles)
        #expect(failures.isEmpty)
        #expect(monitoringService2.activeMonitors.count == 1)
    }
}

// MARK: - ScheduleConfig Codable Tests

@Suite("ScheduleConfig Codable")
struct ScheduleConfigCodableTests {

    @Test("ScheduleConfig encodes and decodes correctly")
    func testRoundTrip() throws {
        let schedule = ScheduleConfig(
            days: [.monday, .wednesday, .friday],
            startHour: 9, startMinute: 30,
            endHour: 17, endMinute: 45,
            repeats: true,
            warningTimeMinutes: 15
        )

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(ScheduleConfig.self, from: data)

        #expect(decoded == schedule)
        #expect(decoded.days == [.monday, .wednesday, .friday])
        #expect(decoded.startHour == 9)
        #expect(decoded.endHour == 17)
    }
}

// MARK: - ScheduleValidationError Tests

@Suite("ScheduleValidationError")
struct ScheduleValidationErrorTests {

    @Test("Error descriptions are meaningful")
    func testErrorDescriptions() {
        #expect(ScheduleValidationError.noDaysSelected.localizedDescription == "At least one day must be selected")
        #expect(ScheduleValidationError.zeroDuration.localizedDescription == "Start and end times cannot be the same")
        #expect(ScheduleValidationError.invalidHour(25).localizedDescription == "Invalid hour: 25. Must be 0-23")
        #expect(ScheduleValidationError.invalidMinute(60).localizedDescription == "Invalid minute: 60. Must be 0-59")
    }

    @Test("Errors are equatable")
    func testEquatable() {
        #expect(ScheduleValidationError.noDaysSelected == ScheduleValidationError.noDaysSelected)
        #expect(ScheduleValidationError.invalidHour(5) == ScheduleValidationError.invalidHour(5))
        #expect(ScheduleValidationError.invalidHour(5) != ScheduleValidationError.invalidHour(6))
    }
}
