import Testing
import Foundation
import SwiftData
@testable import FocusCore
@testable import Focus

// MARK: - ChartDataBuilder Tests

@Suite("ChartDataBuilder Tests", .serialized)
@MainActor
struct ChartDataBuilderTests {

    let builder = ChartDataBuilder()
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

    // MARK: - Helpers

    private func dateAt(
        year: Int, month: Int, day: Int,
        hour: Int = 10, minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    private func makeSession(
        date: Date,
        duration: TimeInterval = 1800,
        status: SessionStatus = .completed
    ) -> DeepFocusSession {
        let session = DeepFocusSession(
            startTime: date,
            configuredDuration: duration,
            remainingSeconds: status == .completed ? 0 : duration,
            status: status
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Daily Bar Chart: Single Data Point

    @Test("Single data point produces one bar chart entry")
    func singleDataPoint() {
        let date = dateAt(year: 2026, month: 4, day: 1)
        let session = makeSession(date: date, duration: 3600)

        let data = builder.buildDailyBarChartData(
            sessions: [session],
            startDate: date,
            endDate: date,
            calendar: calendar
        )

        #expect(data.count == 1)
        #expect(data[0].value == 3600)
    }

    // MARK: - Daily Bar Chart: 7 Days

    @Test("7 days of data produces 7 bar chart entries")
    func sevenDays() {
        let sessions = (0..<7).map { dayOffset -> DeepFocusSession in
            let date = dateAt(year: 2026, month: 4, day: 1 + dayOffset)
            return makeSession(date: date, duration: 1800)
        }

        let data = builder.buildDailyBarChartData(
            sessions: sessions,
            startDate: dateAt(year: 2026, month: 4, day: 1),
            endDate: dateAt(year: 2026, month: 4, day: 7),
            calendar: calendar
        )

        #expect(data.count == 7)
        for point in data {
            #expect(point.value == 1800)
        }
    }

    // MARK: - Daily Bar Chart: 30 Days

    @Test("30-day range produces 30 entries including zero days")
    func thirtyDays() {
        // Only seed a few days — remaining days should be zero
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 1), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 15), duration: 3600)
        let s3 = makeSession(date: dateAt(year: 2026, month: 3, day: 30), duration: 5400)

        let data = builder.buildDailyBarChartData(
            sessions: [s1, s2, s3],
            startDate: dateAt(year: 2026, month: 3, day: 1),
            endDate: dateAt(year: 2026, month: 3, day: 30),
            calendar: calendar
        )

        #expect(data.count == 30)

        // Count non-zero entries
        let nonZero = data.filter { $0.value > 0 }
        #expect(nonZero.count == 3)
    }

    // MARK: - Daily Bar Chart: 180+ Days

    @Test("180-day range produces 180+ entries")
    func oneHundredEightyDays() {
        // Just a few sessions spread over 180 days
        let sessions = [1, 30, 60, 90, 120, 150, 180].map { dayOffset -> DeepFocusSession in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: dateAt(year: 2026, month: 4, day: 1))!
            return makeSession(date: date, duration: 1800)
        }

        let startDate = calendar.date(byAdding: .day, value: -180, to: dateAt(year: 2026, month: 4, day: 1))!
        let data = builder.buildDailyBarChartData(
            sessions: sessions,
            startDate: startDate,
            endDate: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )

        #expect(data.count == 181) // 180 + today
    }

    // MARK: - Daily Bar Chart: Zero Values at Baseline

    @Test("Days with no sessions produce zero values at baseline")
    func zeroValuesAtBaseline() {
        let session = makeSession(date: dateAt(year: 2026, month: 4, day: 3), duration: 1800)

        let data = builder.buildDailyBarChartData(
            sessions: [session],
            startDate: dateAt(year: 2026, month: 4, day: 1),
            endDate: dateAt(year: 2026, month: 4, day: 5),
            calendar: calendar
        )

        #expect(data.count == 5)
        // Days 1, 2, 4, 5 should be 0; day 3 should be 1800
        #expect(data[0].value == 0) // April 1
        #expect(data[1].value == 0) // April 2
        #expect(data[2].value == 1800) // April 3
        #expect(data[3].value == 0) // April 4
        #expect(data[4].value == 0) // April 5
    }

    // MARK: - Daily Bar Chart: Only Completed Sessions

    @Test("Abandoned sessions excluded from bar chart data")
    func abandonedExcludedFromBarChart() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 1800, status: .completed)
        let s2 = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 3600, status: .abandoned)

        let data = builder.buildDailyBarChartData(
            sessions: [s1, s2],
            startDate: dateAt(year: 2026, month: 4, day: 1),
            endDate: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )

        #expect(data.count == 1)
        #expect(data[0].value == 1800) // Only completed session
    }

    // MARK: - Daily Bar Chart: Large Values Scale Correctly

    @Test("Large values (8+ hours) scale correctly")
    func largeValuesScale() {
        let session = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 28800) // 8 hours

        let data = builder.buildDailyBarChartData(
            sessions: [session],
            startDate: dateAt(year: 2026, month: 4, day: 1),
            endDate: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )

        #expect(data.count == 1)
        #expect(data[0].value == 28800)
    }

    // MARK: - Daily Bar Chart: Multiple Sessions Same Day Aggregate

    @Test("Multiple sessions on same day aggregate correctly")
    func multipleSameDayAggregate() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 4, day: 1, hour: 9), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 4, day: 1, hour: 14), duration: 3600)

        let data = builder.buildDailyBarChartData(
            sessions: [s1, s2],
            startDate: dateAt(year: 2026, month: 4, day: 1),
            endDate: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )

        #expect(data.count == 1)
        #expect(data[0].value == 5400) // 1800 + 3600
    }

    // MARK: - Last N Days Convenience

    @Test("buildDailyBarChartData lastDays returns correct count")
    func lastNDays() {
        let now = dateAt(year: 2026, month: 4, day: 6)
        let session = makeSession(date: dateAt(year: 2026, month: 4, day: 3), duration: 1800)

        let data = builder.buildDailyBarChartData(
            sessions: [session],
            lastDays: 7,
            now: now,
            calendar: calendar
        )

        #expect(data.count == 7)
    }

    // MARK: - Weekly Line Chart

    @Test("Weekly line chart produces correct number of weeks")
    func weeklyLineChartCount() {
        let now = dateAt(year: 2026, month: 4, day: 6)
        let session = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 3600)

        let data = builder.buildWeeklyLineChartData(
            sessions: [session],
            weeks: 4,
            now: now,
            calendar: calendar
        )

        #expect(data.count == 4)
    }

    @Test("Weekly line chart computes averages per week")
    func weeklyLineChartAverages() {
        let now = dateAt(year: 2026, month: 4, day: 6)
        // Create sessions on multiple days of the current week
        let s1 = makeSession(date: dateAt(year: 2026, month: 4, day: 5), duration: 3600)
        let s2 = makeSession(date: dateAt(year: 2026, month: 4, day: 6), duration: 1800)

        let data = builder.buildWeeklyLineChartData(
            sessions: [s1, s2],
            weeks: 1,
            now: now,
            calendar: calendar
        )

        #expect(data.count == 1)
        // 2 sessions on 2 days: (3600 + 1800) / 2 = 2700
        #expect(data[0].value == 2700)
    }

    @Test("Weekly line chart handles empty weeks")
    func weeklyLineChartEmpty() {
        let now = dateAt(year: 2026, month: 4, day: 6)

        let data = builder.buildWeeklyLineChartData(
            sessions: [],
            weeks: 4,
            now: now,
            calendar: calendar
        )

        #expect(data.count == 4)
        for point in data {
            #expect(point.value == 0)
        }
    }

    // MARK: - Y-Axis Range

    @Test("Y-axis range for empty values returns 0...1")
    func yAxisRangeEmpty() {
        let range = builder.yAxisRange(for: [])
        #expect(range.min == 0)
        #expect(range.max == 1)
    }

    @Test("Y-axis range for all zeros returns 0...1")
    func yAxisRangeAllZeros() {
        let range = builder.yAxisRange(for: [0, 0, 0, 0])
        #expect(range.min == 0)
        #expect(range.max == 1)
    }

    @Test("Y-axis range for all-same values adds padding")
    func yAxisRangeSameValues() {
        let range = builder.yAxisRange(for: [100, 100, 100])
        #expect(range.min == 0)
        // Should have padding above 100
        #expect(range.max > 100)
        #expect(range.max == 100 + 100 * ChartDataBuilder.sameValuePaddingFactor)
    }

    @Test("Y-axis range for varied values starts at 0")
    func yAxisRangeVariedValues() {
        let range = builder.yAxisRange(for: [50, 100, 200])
        #expect(range.min == 0)
        #expect(range.max > 200) // Some top padding
    }

    @Test("Y-axis range for mixed small and large values")
    func yAxisRangeMixedValues() {
        let range = builder.yAxisRange(for: [10, 50000])
        #expect(range.min == 0)
        #expect(range.max > 50000)
    }

    @Test("Y-axis range for single non-zero value adds padding")
    func yAxisRangeSingleValue() {
        let range = builder.yAxisRange(for: [500])
        #expect(range.min == 0)
        // Single value treated as all-same
        #expect(range.max == 500 + 500 * ChartDataBuilder.sameValuePaddingFactor)
    }
}

// MARK: - Large Dataset Performance Tests

@Suite("Large Dataset Performance Tests", .serialized)
@MainActor
struct LargeDatasetPerformanceTests {

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

    // MARK: - Helpers

    /// Seeds N sessions spread over 6 months.
    private func seedSessions(count: Int) {
        let now = Date()
        for i in 0..<count {
            // Spread sessions over 180 days
            let daysAgo = i % 180
            let startTime = calendar.date(
                byAdding: .day,
                value: -daysAgo,
                to: calendar.startOfDay(for: now)
            )!.addingTimeInterval(Double(10 * 3600 + (i % 8) * 3600)) // Stagger times

            let session = DeepFocusSession(
                startTime: startTime,
                configuredDuration: Double(1800 + (i % 4) * 900), // 30–75 min
                remainingSeconds: 0,
                status: i % 10 == 0 ? .abandoned : .completed, // 10% abandoned
                bypassCount: i % 5 == 0 ? 1 : 0,
                breakCount: i % 3 == 0 ? 1 : 0
            )
            context.insert(session)
        }
        try? context.save()
    }

    // MARK: - VAL-STATS-013: Large Dataset Performance

    @Test("Dashboard query with 900+ sessions completes within 500ms")
    func dashboardQueryPerformance() throws {
        seedSessions(count: 950)

        // Verify all sessions are stored
        let allDescriptor = FetchDescriptor<DeepFocusSession>()
        let totalCount = try context.fetchCount(allDescriptor)
        #expect(totalCount == 950)

        // Measure query time
        let startTime = CFAbsoluteTimeGetCurrent()

        let sessions = try context.fetch(FetchDescriptor<DeepFocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        ))

        let completedSessions = sessions.filter { $0.status == .completed }
        let totalFocusTime = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }
        let sessionsCompleted = completedSessions.count

        let queryTime = CFAbsoluteTimeGetCurrent() - startTime

        // Query should complete in under 500ms
        #expect(queryTime < 0.5, "Query took \(queryTime)s, expected < 0.5s")
        #expect(sessionsCompleted > 0)
        #expect(totalFocusTime > 0)
    }

    @Test("Chart data builder with 900+ sessions completes within 500ms")
    func chartDataBuilderPerformance() throws {
        seedSessions(count: 950)

        let sessions = try context.fetch(FetchDescriptor<DeepFocusSession>())
        let builder = ChartDataBuilder()

        // Measure chart data build time
        let startTime = CFAbsoluteTimeGetCurrent()

        let dailyData = builder.buildDailyBarChartData(
            sessions: sessions,
            lastDays: 180,
            calendar: calendar
        )
        let weeklyData = builder.buildWeeklyLineChartData(
            sessions: sessions,
            weeks: 26,
            calendar: calendar
        )

        let buildTime = CFAbsoluteTimeGetCurrent() - startTime

        // Chart build should complete in under 500ms
        #expect(buildTime < 0.5, "Chart build took \(buildTime)s, expected < 0.5s")
        #expect(dailyData.count == 180)
        #expect(weeklyData.count == 26)
    }

    @Test("Dashboard render simulation with 900+ sessions completes within 2 seconds")
    func dashboardRenderPerformance() throws {
        seedSessions(count: 950)

        let startTime = CFAbsoluteTimeGetCurrent()

        // Simulate full dashboard render: fetch + compute all metrics
        let sessions = try context.fetch(FetchDescriptor<DeepFocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        ))

        let completedSessions = sessions.filter { $0.status == .completed }
        let totalFocusTime = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }
        let sessionsCompleted = completedSessions.count

        let streakCalculator = StreakCalculator()
        let streak = streakCalculator.currentStreak(sessions: sessions, calendar: calendar)

        let chartBuilder = ChartDataBuilder()
        let dailyData = chartBuilder.buildDailyBarChartData(
            sessions: sessions,
            lastDays: 7,
            calendar: calendar
        )
        let weeklyData = chartBuilder.buildWeeklyLineChartData(
            sessions: sessions,
            weeks: 12,
            calendar: calendar
        )

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime

        // Full render should be under 2 seconds
        #expect(totalTime < 2.0, "Dashboard render took \(totalTime)s, expected < 2.0s")
        #expect(totalFocusTime > 0)
        #expect(sessionsCompleted > 0)
        #expect(dailyData.count == 7)
        #expect(weeklyData.count == 12)
        _ = streak // Use to silence warning
    }

    @Test("FetchDescriptor with fetchLimit for pagination")
    func paginatedFetch() throws {
        seedSessions(count: 950)

        // Paginated fetch: first 50 sessions
        var descriptor = FetchDescriptor<DeepFocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        let page1 = try context.fetch(descriptor)
        #expect(page1.count == 50)

        // Paginated fetch with offset
        descriptor.fetchOffset = 50
        let page2 = try context.fetch(descriptor)
        #expect(page2.count == 50)

        // Pages should not overlap
        let page1IDs = Set(page1.map { $0.id })
        let page2IDs = Set(page2.map { $0.id })
        #expect(page1IDs.isDisjoint(with: page2IDs))
    }
}

// MARK: - Analytics Totals Consistency Tests (VAL-CROSS-012)

@Suite("AnalyticsTotalsConsistency Tests", .serialized)
@MainActor
struct AnalyticsTotalsConsistencyTests {

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

    // MARK: - Helpers

    private func dateAt(
        year: Int, month: Int, day: Int,
        hour: Int = 10
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }

    private func makeSession(
        date: Date,
        duration: TimeInterval,
        status: SessionStatus = .completed
    ) -> DeepFocusSession {
        let session = DeepFocusSession(
            startTime: date,
            configuredDuration: duration,
            remainingSeconds: status == .completed ? 0 : duration,
            status: status
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Total Equals Sum of Individual Sessions

    @Test("Dashboard total focus time equals sum of individual completed session durations")
    func totalEqualsSumOfSessions() {
        let durations: [TimeInterval] = [1800, 3600, 2700, 5400, 900]
        var sessions: [DeepFocusSession] = []
        for (i, duration) in durations.enumerated() {
            let session = makeSession(
                date: dateAt(year: 2026, month: 4, day: 1 + i),
                duration: duration
            )
            sessions.append(session)
        }

        // Add abandoned sessions (should not affect total)
        let _ = makeSession(
            date: dateAt(year: 2026, month: 4, day: 1),
            duration: 7200,
            status: .abandoned
        )

        let vm = DashboardViewModel(modelContext: context)
        let expectedTotal = durations.reduce(0, +) // 14400
        #expect(vm.totalFocusTime == expectedTotal)
    }

    @Test("Dashboard total consistent with sum after multiple sessions added")
    func totalConsistentAfterMultipleAdds() {
        let vm = DashboardViewModel(modelContext: context)
        var runningTotal: TimeInterval = 0

        for i in 0..<10 {
            let duration = Double(1800 + i * 300) // 1800, 2100, 2400, ...
            let _ = makeSession(
                date: dateAt(year: 2026, month: 4, day: 1 + i % 5),
                duration: duration
            )
            runningTotal += duration
            vm.refresh()
            #expect(vm.totalFocusTime == runningTotal, "After adding session \(i+1)")
        }
    }

    @Test("No double-counting: total equals individual sum for various date ranges")
    func noDoubleCounting() {
        let sessions = (0..<20).map { i -> DeepFocusSession in
            makeSession(
                date: dateAt(year: 2026, month: 3, day: 1 + i),
                duration: 1800
            )
        }

        let vm = DashboardViewModel(modelContext: context)
        let expectedTotal: TimeInterval = 1800 * 20 // 36000
        #expect(vm.totalFocusTime == expectedTotal)

        // Verify sum of individual durations matches
        let individualSum = sessions.reduce(0.0) { $0 + $1.configuredDuration }
        #expect(vm.totalFocusTime == individualSum)
    }

    // MARK: - Monthly Averages Use Active Days (Not Calendar Days)

    @Test("Monthly average divides by active days not calendar days")
    func monthlyAverageDividesByActiveDays() {
        let calculator = MonthlyAverageCalculator()

        // March 2026 has 31 days. Create sessions on only 5 days.
        let sessions = [1, 5, 10, 15, 25].map { day in
            makeSession(
                date: dateAt(year: 2026, month: 3, day: day),
                duration: 3600
            )
        }

        let avg = calculator.monthlyAverage(
            sessions: sessions,
            year: 2026,
            month: 3,
            calendar: calendar
        )

        // Should divide by 5 active days, not 31 calendar days
        // Total: 5 * 3600 = 18000. Average: 18000 / 5 = 3600
        #expect(avg == 3600.0)
        // If it divided by calendar days it would be 18000/31 ≈ 580.6
        #expect(avg != 18000.0 / 31.0)
    }

    @Test("Weekly average divides by active days not 7")
    func weeklyAverageDividesByActiveDays() {
        let calculator = WeeklyAverageCalculator()

        // Create sessions on only 3 days of the week
        let s1 = makeSession(
            date: dateAt(year: 2026, month: 3, day: 30), // Monday
            duration: 3600
        )
        let s2 = makeSession(
            date: dateAt(year: 2026, month: 3, day: 31), // Tuesday
            duration: 1800
        )
        let s3 = makeSession(
            date: dateAt(year: 2026, month: 4, day: 1), // Wednesday
            duration: 5400
        )

        let avg = calculator.weeklyAverage(
            sessions: [s1, s2, s3],
            weekContaining: dateAt(year: 2026, month: 3, day: 31),
            calendar: calendar
        )

        // Should divide by 3 active days, not 7
        // Total: 3600 + 1800 + 5400 = 10800. Average: 10800 / 3 = 3600
        #expect(avg == 3600.0)
    }

    @Test("Monthly average with only abandoned sessions returns 0")
    func monthlyAverageAbandonedOnly() {
        let calculator = MonthlyAverageCalculator()

        let _ = makeSession(
            date: dateAt(year: 2026, month: 3, day: 15),
            duration: 3600,
            status: .abandoned
        )

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let avg = calculator.monthlyAverage(
            sessions: sessions,
            year: 2026,
            month: 3,
            calendar: calendar
        )
        #expect(avg == 0)
    }

    // MARK: - Mixed Sessions: Totals Consistency

    @Test("Mixed completed and abandoned sessions: totals only count completed")
    func mixedSessionsTotals() {
        let completedDurations: [TimeInterval] = [1800, 3600, 5400]
        let abandonedDurations: [TimeInterval] = [2700, 900]

        for (i, duration) in completedDurations.enumerated() {
            let _ = makeSession(
                date: dateAt(year: 2026, month: 4, day: 1 + i),
                duration: duration,
                status: .completed
            )
        }
        for (i, duration) in abandonedDurations.enumerated() {
            let _ = makeSession(
                date: dateAt(year: 2026, month: 4, day: 4 + i),
                duration: duration,
                status: .abandoned
            )
        }

        let vm = DashboardViewModel(modelContext: context)
        let expectedTotal = completedDurations.reduce(0, +) // 10800
        #expect(vm.totalFocusTime == expectedTotal)
        #expect(vm.sessionsCompleted == 3)
    }

    // MARK: - Large Dataset Totals Consistency

    @Test("Large dataset totals consistency: 900+ sessions")
    func largeDatasetTotalsConsistency() {
        var expectedTotal: TimeInterval = 0
        var expectedCompleted = 0

        for i in 0..<950 {
            let duration = Double(1800 + (i % 4) * 900)
            let status: SessionStatus = i % 10 == 0 ? .abandoned : .completed
            let date = calendar.date(
                byAdding: .day,
                value: -(i % 180),
                to: calendar.startOfDay(for: Date())
            )!.addingTimeInterval(36000)

            let session = DeepFocusSession(
                startTime: date,
                configuredDuration: duration,
                remainingSeconds: status == .completed ? 0 : duration,
                status: status
            )
            context.insert(session)

            if status == .completed {
                expectedTotal += duration
                expectedCompleted += 1
            }
        }
        try? context.save()

        let vm = DashboardViewModel(modelContext: context)
        #expect(vm.totalFocusTime == expectedTotal)
        #expect(vm.sessionsCompleted == expectedCompleted)
    }
}
