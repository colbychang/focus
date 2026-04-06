import Testing
import Foundation
import SwiftData
@testable import FocusCore
@testable import Focus

// MARK: - StreakCalculator Tests

@Suite("StreakCalculator Tests", .serialized)
@MainActor
struct StreakCalculatorTests {

    let calculator = StreakCalculator()
    var container: ModelContainer
    var context: ModelContext
    var calendar: Calendar

    init() throws {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        calendar = cal
    }

    // MARK: - Helper

    private func makeSession(
        daysAgo: Int,
        status: SessionStatus = .completed,
        duration: TimeInterval = 1800
    ) -> DeepFocusSession {
        let startTime = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
            .addingTimeInterval(36000) // 10 AM
        let session = DeepFocusSession(
            startTime: startTime,
            configuredDuration: duration,
            remainingSeconds: status == .completed ? 0 : duration,
            status: status
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Empty Data

    @Test("Empty sessions returns 0 streak")
    func emptySessionsReturnsZero() {
        let streak = calculator.currentStreak(sessions: [], calendar: calendar)
        #expect(streak == 0)
    }

    // MARK: - Single Day

    @Test("Single completed session today gives streak of 1")
    func singleSessionToday() {
        let session = makeSession(daysAgo: 0)
        let streak = calculator.currentStreak(sessions: [session], calendar: calendar)
        #expect(streak == 1)
    }

    @Test("Single completed session yesterday gives streak of 1 (grace period)")
    func singleSessionYesterday() {
        let session = makeSession(daysAgo: 1)
        let streak = calculator.currentStreak(sessions: [session], calendar: calendar)
        #expect(streak == 1)
    }

    // MARK: - Consecutive Days

    @Test("Three consecutive days gives streak of 3")
    func threeConsecutiveDays() {
        let s1 = makeSession(daysAgo: 0)
        let s2 = makeSession(daysAgo: 1)
        let s3 = makeSession(daysAgo: 2)
        let streak = calculator.currentStreak(sessions: [s1, s2, s3], calendar: calendar)
        #expect(streak == 3)
    }

    @Test("Five consecutive days gives streak of 5")
    func fiveConsecutiveDays() {
        let sessions = (0..<5).map { makeSession(daysAgo: $0) }
        let streak = calculator.currentStreak(sessions: sessions, calendar: calendar)
        #expect(streak == 5)
    }

    // MARK: - Gap Resets Streak

    @Test("Gap of one day resets streak")
    func gapResetsStreak() {
        // Sessions on days 0, 1, and 3 (gap at day 2)
        let s1 = makeSession(daysAgo: 0)
        let s2 = makeSession(daysAgo: 1)
        let s3 = makeSession(daysAgo: 3)
        let streak = calculator.currentStreak(sessions: [s1, s2, s3], calendar: calendar)
        #expect(streak == 2) // Only today + yesterday
    }

    @Test("Old sessions with no recent activity gives streak of 0")
    func oldSessionsNoRecent() {
        // Session 5 days ago, nothing since
        let session = makeSession(daysAgo: 5)
        let streak = calculator.currentStreak(sessions: [session], calendar: calendar)
        #expect(streak == 0) // No session today or yesterday
    }

    // MARK: - Multiple Sessions Per Day

    @Test("Multiple sessions same day counts as 1 active day")
    func multipleSessionsSameDay() {
        let s1 = makeSession(daysAgo: 0)
        let s2 = makeSession(daysAgo: 0, duration: 3600)
        let s3 = makeSession(daysAgo: 1)
        let streak = calculator.currentStreak(sessions: [s1, s2, s3], calendar: calendar)
        #expect(streak == 2)
    }

    // MARK: - Abandoned Sessions Excluded

    @Test("Abandoned sessions do not count toward streak")
    func abandonedSessionsExcluded() {
        let _ = makeSession(daysAgo: 0, status: .abandoned)
        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let streak = calculator.currentStreak(sessions: sessions, calendar: calendar)
        #expect(streak == 0) // Only abandoned, should be 0
    }

    @Test("Abandoned sessions between completed sessions do not break gap logic")
    func abandonedDoesNotCount() {
        let s1 = makeSession(daysAgo: 0, status: .completed)
        let _ = makeSession(daysAgo: 1, status: .abandoned)
        let streak = calculator.currentStreak(sessions: [s1], calendar: calendar)
        #expect(streak == 1) // Only today's completed session
    }

    // MARK: - Grace Period

    @Test("Grace period: no session today but session yesterday gives streak of 1")
    func gracePeriodYesterday() {
        let session = makeSession(daysAgo: 1)
        let streak = calculator.currentStreak(sessions: [session], calendar: calendar)
        #expect(streak == 1)
    }

    @Test("Grace period: sessions yesterday and day before gives streak of 2")
    func gracePeriodConsecutive() {
        let s1 = makeSession(daysAgo: 1)
        let s2 = makeSession(daysAgo: 2)
        let streak = calculator.currentStreak(sessions: [s1, s2], calendar: calendar)
        #expect(streak == 2)
    }

    @Test("No grace period needed when today has a session")
    func noGracePeriodNeeded() {
        let s1 = makeSession(daysAgo: 0)
        let s2 = makeSession(daysAgo: 1)
        let streak = calculator.currentStreak(sessions: [s1, s2], calendar: calendar)
        #expect(streak == 2)
    }
}

// MARK: - DashboardViewModel Tests

@Suite("DashboardViewModel Tests", .serialized)
@MainActor
struct DashboardViewModelTests {

    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - Helpers

    private func makeSession(
        daysAgo: Int = 0,
        duration: TimeInterval = 1800,
        status: SessionStatus = .completed,
        bypassCount: Int = 0,
        breakCount: Int = 0,
        totalBreakDuration: TimeInterval = 0
    ) {
        let startTime = Calendar.current.date(
            byAdding: .day,
            value: -daysAgo,
            to: Calendar.current.startOfDay(for: Date())
        )!.addingTimeInterval(36000)

        let session = DeepFocusSession(
            startTime: startTime,
            configuredDuration: duration,
            remainingSeconds: status == .completed ? 0 : duration,
            status: status,
            bypassCount: bypassCount,
            breakCount: breakCount,
            totalBreakDuration: totalBreakDuration
        )
        context.insert(session)
        try? context.save()
    }

    // MARK: - Empty State

    @Test("Empty state shows all zeros and isEmpty true")
    func emptyState() {
        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.isEmpty == true)
        #expect(vm.totalFocusTime == 0)
        #expect(vm.sessionsCompleted == 0)
        #expect(vm.currentStreak == 0)
        #expect(vm.allSessions.isEmpty)
    }

    // MARK: - Total Focus Time

    @Test("Total focus time sums completed sessions only")
    func totalFocusTimeCompletedOnly() {
        makeSession(duration: 1800, status: .completed) // 30 min
        makeSession(duration: 3600, status: .completed) // 60 min
        makeSession(duration: 900, status: .abandoned)   // 15 min (excluded)

        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.totalFocusTime == 5400) // 30 + 60 = 90 min = 5400 sec
    }

    @Test("Abandoned sessions excluded from total focus time")
    func abandonedExcluded() {
        makeSession(duration: 3600, status: .abandoned)
        makeSession(duration: 1800, status: .abandoned)

        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.totalFocusTime == 0)
    }

    // MARK: - Sessions Completed Count

    @Test("Sessions completed count only counts completed sessions")
    func sessionsCompletedCount() {
        makeSession(status: .completed)
        makeSession(status: .completed)
        makeSession(status: .abandoned)

        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.sessionsCompleted == 2)
    }

    // MARK: - Current Streak

    @Test("Current streak computed correctly with seeded data")
    func streakWithSeededData() {
        makeSession(daysAgo: 0, status: .completed)
        makeSession(daysAgo: 1, status: .completed)
        makeSession(daysAgo: 2, status: .completed)

        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.currentStreak == 3)
    }

    // MARK: - All Sessions Sorted

    @Test("All sessions sorted by startTime descending")
    func sessionsSortedDescending() {
        makeSession(daysAgo: 2, duration: 1800, status: .completed)
        makeSession(daysAgo: 0, duration: 3600, status: .completed)
        makeSession(daysAgo: 1, duration: 900, status: .abandoned)

        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.allSessions.count == 3)
        // Most recent first
        #expect(vm.allSessions[0].configuredDuration == 3600) // daysAgo: 0
        #expect(vm.allSessions[1].configuredDuration == 900)  // daysAgo: 1
        #expect(vm.allSessions[2].configuredDuration == 1800) // daysAgo: 2
    }

    // MARK: - Reactive Updates (VAL-STATS-014)

    @Test("Statistics update after new session added and refresh called")
    func reactiveUpdate() {
        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.isEmpty == true)
        #expect(vm.sessionsCompleted == 0)

        // Add a session
        makeSession(duration: 1800, status: .completed)

        // Refresh should pick up the new session
        vm.refresh()
        #expect(vm.isEmpty == false)
        #expect(vm.sessionsCompleted == 1)
        #expect(vm.totalFocusTime == 1800)
    }

    @Test("Multiple refreshes show updated values")
    func multipleRefreshes() {
        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.sessionsCompleted == 0)

        makeSession(duration: 1800, status: .completed)
        vm.refresh()
        #expect(vm.sessionsCompleted == 1)

        makeSession(duration: 3600, status: .completed)
        vm.refresh()
        #expect(vm.sessionsCompleted == 2)
        #expect(vm.totalFocusTime == 5400)
    }

    // MARK: - Formatting Helpers

    @Test("Format duration shows correct values")
    func formatDuration() {
        #expect(DashboardViewModel.formatDuration(0) == "0m")
        #expect(DashboardViewModel.formatDuration(2700) == "45m")
        #expect(DashboardViewModel.formatDuration(5400) == "1h 30m")
        #expect(DashboardViewModel.formatDuration(7200) == "2h 0m")
    }

    @Test("Format duration detailed shows H:MM:SS")
    func formatDurationDetailed() {
        #expect(DashboardViewModel.formatDurationDetailed(0) == "0:00")
        #expect(DashboardViewModel.formatDurationDetailed(65) == "1:05")
        #expect(DashboardViewModel.formatDurationDetailed(3661) == "1:01:01")
        #expect(DashboardViewModel.formatDurationDetailed(7200) == "2:00:00")
    }

    @Test("Status info returns correct label and color")
    func statusInfo() {
        #expect(DashboardViewModel.statusInfo(for: .completed).label == "Completed")
        #expect(DashboardViewModel.statusInfo(for: .completed).colorName == "green")
        #expect(DashboardViewModel.statusInfo(for: .abandoned).label == "Abandoned")
        #expect(DashboardViewModel.statusInfo(for: .abandoned).colorName == "red")
    }

    @Test("Mode type label returns Deep Focus for sessions without focus mode")
    func modeTypeLabel() {
        let session = DeepFocusSession(
            configuredDuration: 1800,
            status: .completed
        )
        #expect(DashboardViewModel.modeTypeLabel(for: session) == "Deep Focus")
    }
}
