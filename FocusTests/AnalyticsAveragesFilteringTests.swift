import Testing
import Foundation
import SwiftData
@testable import FocusCore
@testable import Focus

// MARK: - WeeklyAverageCalculator Tests

@Suite("WeeklyAverageCalculator Tests", .serialized)
@MainActor
struct WeeklyAverageCalculatorTests {

    let calculator = WeeklyAverageCalculator()
    var container: ModelContainer
    var context: ModelContext
    var calendar: Calendar

    init() throws {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        // Use Gregorian calendar with known timezone
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        cal.firstWeekday = 1 // Sunday
        calendar = cal
    }

    // MARK: - Helpers

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

    // MARK: - Full Week

    @Test("Full week with sessions every day returns correct average")
    func fullWeekAverage() {
        // Week of 2026-03-29 (Sun) to 2026-04-04 (Sat)
        // Sunday March 29 through Saturday April 4
        let sessions = (0..<7).map { dayOffset -> DeepFocusSession in
            let date = dateAt(year: 2026, month: 3, day: 29 + dayOffset, hour: 10)
            return makeSession(date: date, duration: Double(1800 + dayOffset * 600))
        }
        // Durations: 1800, 2400, 3000, 3600, 4200, 4800, 5400
        // Total: 25200, Average: 25200/7 = 3600

        let avg = calculator.weeklyAverage(
            sessions: sessions,
            weekContaining: dateAt(year: 2026, month: 3, day: 31),
            calendar: calendar
        )
        #expect(avg == 3600.0)
    }

    // MARK: - Single Day

    @Test("Single day in week returns that day's total as average")
    func singleDayAverage() {
        let session = makeSession(
            date: dateAt(year: 2026, month: 4, day: 1),
            duration: 3600
        )

        let avg = calculator.weeklyAverage(
            sessions: [session],
            weekContaining: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )
        #expect(avg == 3600.0)
    }

    // MARK: - Partial Week

    @Test("Partial week averages over days with data only")
    func partialWeekAverage() {
        // 3 days of data in a week
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 30), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 31), duration: 3600)
        let s3 = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 5400)

        let avg = calculator.weeklyAverage(
            sessions: [s1, s2, s3],
            weekContaining: dateAt(year: 2026, month: 3, day: 31),
            calendar: calendar
        )
        // Total: 10800, 3 days with data
        #expect(avg == 3600.0)
    }

    // MARK: - Multiple Sessions Same Day

    @Test("Multiple sessions on same day aggregate correctly")
    func multipleSameDay() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 4, day: 1, hour: 9), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 4, day: 1, hour: 14), duration: 1800)

        let avg = calculator.weeklyAverage(
            sessions: [s1, s2],
            weekContaining: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )
        // Total: 3600, 1 day with data
        #expect(avg == 3600.0)
    }

    // MARK: - Empty Week

    @Test("Empty week returns 0")
    func emptyWeek() {
        let avg = calculator.weeklyAverage(
            sessions: [],
            weekContaining: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )
        #expect(avg == 0)
    }

    // MARK: - Abandoned Sessions Excluded

    @Test("Abandoned sessions are excluded from weekly average")
    func abandonedExcluded() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 3600, status: .completed)
        let s2 = makeSession(date: dateAt(year: 2026, month: 4, day: 2), duration: 7200, status: .abandoned)

        let avg = calculator.weeklyAverage(
            sessions: [s1, s2],
            weekContaining: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )
        // Only completed: 3600 / 1 day = 3600
        #expect(avg == 3600.0)
    }

    // MARK: - Week Boundary Handling

    @Test("Week boundary per locale: Sunday start")
    func weekBoundarySunday() {
        var sundayCal = calendar
        sundayCal.firstWeekday = 1 // Sunday

        // Saturday April 4 and Sunday April 5 should be in different weeks
        let satSession = makeSession(date: dateAt(year: 2026, month: 4, day: 4), duration: 1800)
        let sunSession = makeSession(date: dateAt(year: 2026, month: 4, day: 5), duration: 3600)

        let satAvg = calculator.weeklyAverage(
            sessions: [satSession, sunSession],
            weekContaining: dateAt(year: 2026, month: 4, day: 4),
            calendar: sundayCal
        )
        // Saturday is in one week, only satSession should be counted
        #expect(satAvg == 1800.0)

        let sunAvg = calculator.weeklyAverage(
            sessions: [satSession, sunSession],
            weekContaining: dateAt(year: 2026, month: 4, day: 5),
            calendar: sundayCal
        )
        // Sunday is in next week, only sunSession
        #expect(sunAvg == 3600.0)
    }

    @Test("Week boundary per locale: Monday start")
    func weekBoundaryMonday() {
        var mondayCal = calendar
        mondayCal.firstWeekday = 2 // Monday

        // Sunday April 5 and Monday April 6 should be in different weeks
        let sunSession = makeSession(date: dateAt(year: 2026, month: 4, day: 5), duration: 1800)
        let monSession = makeSession(date: dateAt(year: 2026, month: 4, day: 6), duration: 3600)

        let sunAvg = calculator.weeklyAverage(
            sessions: [sunSession, monSession],
            weekContaining: dateAt(year: 2026, month: 4, day: 5),
            calendar: mondayCal
        )
        // Sunday is the last day of the week when Monday is first
        #expect(sunAvg == 1800.0)

        let monAvg = calculator.weeklyAverage(
            sessions: [sunSession, monSession],
            weekContaining: dateAt(year: 2026, month: 4, day: 6),
            calendar: mondayCal
        )
        #expect(monAvg == 3600.0)
    }

    // MARK: - Week Date Range

    @Test("Week date range returns correct start and end")
    func weekDateRange() {
        let range = calculator.weekDateRange(
            for: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )
        // April 1, 2026 is a Wednesday. With Sunday start, week is March 29 - April 4
        let expectedStart = calendar.startOfDay(for: dateAt(year: 2026, month: 3, day: 29))
        let expectedEnd = calendar.startOfDay(for: dateAt(year: 2026, month: 4, day: 5))
        #expect(range.start == expectedStart)
        #expect(range.end == expectedEnd)
    }
}

// MARK: - MonthlyAverageCalculator Tests

@Suite("MonthlyAverageCalculator Tests", .serialized)
@MainActor
struct MonthlyAverageCalculatorTests {

    let calculator = MonthlyAverageCalculator()
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

    // MARK: - Variable Month Lengths

    @Test("January (31 days) average computes correctly")
    func january31Days() {
        // Sessions on 5 days in January
        let sessions = [1, 5, 10, 15, 31].map { day in
            makeSession(date: dateAt(year: 2026, month: 1, day: day), duration: 3600)
        }

        let avg = calculator.monthlyAverage(
            sessions: sessions,
            year: 2026,
            month: 1,
            calendar: calendar
        )
        // Total: 18000, 5 days with data
        #expect(avg == 3600.0)
    }

    @Test("February (28 days, non-leap) average computes correctly")
    func february28Days() {
        // 2026 is not a leap year
        let sessions = [1, 14, 28].map { day in
            makeSession(date: dateAt(year: 2026, month: 2, day: day), duration: 1800)
        }

        let avg = calculator.monthlyAverage(
            sessions: sessions,
            year: 2026,
            month: 2,
            calendar: calendar
        )
        // Total: 5400, 3 days
        #expect(avg == 1800.0)
    }

    @Test("April (30 days) average computes correctly")
    func april30Days() {
        let sessions = [1, 15, 30].map { day in
            makeSession(date: dateAt(year: 2026, month: 4, day: day), duration: 2400)
        }

        let avg = calculator.monthlyAverage(
            sessions: sessions,
            year: 2026,
            month: 4,
            calendar: calendar
        )
        // Total: 7200, 3 days
        #expect(avg == 2400.0)
    }

    // MARK: - Empty Month

    @Test("Empty month returns 0")
    func emptyMonth() {
        let avg = calculator.monthlyAverage(
            sessions: [],
            year: 2026,
            month: 3,
            calendar: calendar
        )
        #expect(avg == 0)
    }

    @Test("Month with only abandoned sessions returns 0")
    func abandonedOnlyMonth() {
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

    // MARK: - Partial Month

    @Test("Partial month averages over days with data only")
    func partialMonth() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 1), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 2), duration: 3600)

        let avg = calculator.monthlyAverage(
            sessions: [s1, s2],
            year: 2026,
            month: 3,
            calendar: calendar
        )
        // Total: 5400, 2 days with data
        #expect(avg == 2700.0)
    }

    // MARK: - Leap Year

    @Test("Leap year February (29 days) handles Feb 29 session")
    func leapYearFebruary() {
        // 2028 is a leap year
        let s1 = makeSession(date: dateAt(year: 2028, month: 2, day: 28), duration: 3600)
        let s2 = makeSession(date: dateAt(year: 2028, month: 2, day: 29), duration: 1800)

        let avg = calculator.monthlyAverage(
            sessions: [s1, s2],
            year: 2028,
            month: 2,
            calendar: calendar
        )
        // Total: 5400, 2 days with data
        #expect(avg == 2700.0)
    }

    @Test("Leap year days in month returns 29 for February")
    func leapYearDaysInMonth() {
        let days = calculator.daysInMonth(year: 2028, month: 2, calendar: calendar)
        #expect(days == 29)
    }

    @Test("Non-leap year days in month returns 28 for February")
    func nonLeapYearDaysInMonth() {
        let days = calculator.daysInMonth(year: 2026, month: 2, calendar: calendar)
        #expect(days == 28)
    }

    @Test("Days in month returns 31 for January")
    func daysInJanuary() {
        let days = calculator.daysInMonth(year: 2026, month: 1, calendar: calendar)
        #expect(days == 31)
    }

    @Test("Days in month returns 30 for April")
    func daysInApril() {
        let days = calculator.daysInMonth(year: 2026, month: 4, calendar: calendar)
        #expect(days == 30)
    }

    // MARK: - Sessions From Other Months Excluded

    @Test("Sessions from adjacent months are excluded")
    func adjacentMonthsExcluded() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 2, day: 28), duration: 3600)
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 1), duration: 1800)
        let s3 = makeSession(date: dateAt(year: 2026, month: 4, day: 1), duration: 7200)

        let avg = calculator.monthlyAverage(
            sessions: [s1, s2, s3],
            year: 2026,
            month: 3,
            calendar: calendar
        )
        // Only s2 is in March: 1800 / 1 day
        #expect(avg == 1800.0)
    }

    // MARK: - Multiple Sessions Same Day

    @Test("Multiple sessions same day counted as one day for average denominator")
    func multipleSameDay() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 15, hour: 9), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 15, hour: 14), duration: 1800)

        let avg = calculator.monthlyAverage(
            sessions: [s1, s2],
            year: 2026,
            month: 3,
            calendar: calendar
        )
        // Total: 3600, 1 day with data
        #expect(avg == 3600.0)
    }
}

// MARK: - DateRangeFilter Tests

@Suite("DateRangeFilter Tests", .serialized)
@MainActor
struct DateRangeFilterTests {

    let filter = DateRangeFilter()
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

    private func dateAt(
        year: Int, month: Int, day: Int,
        hour: Int = 10, minute: Int = 0, second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    // MARK: - Basic Filtering

    @Test("Filter returns sessions within date range")
    func basicFiltering() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 1))
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 15))
        let s3 = makeSession(date: dateAt(year: 2026, month: 3, day: 31))
        let s4 = makeSession(date: dateAt(year: 2026, month: 4, day: 1))

        let result = filter.filterSessions(
            [s1, s2, s3, s4],
            from: dateAt(year: 2026, month: 3, day: 1),
            to: dateAt(year: 2026, month: 4, day: 1),
            calendar: calendar
        )

        // s1, s2, s3 are in March; s4 is April 1 (excluded as endDate is exclusive)
        #expect(result.count == 3)
    }

    // MARK: - Single Day Range

    @Test("Single day filter returns sessions on that day only")
    func singleDayFilter() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 15, hour: 0, minute: 0))
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 15, hour: 14))
        let s3 = makeSession(date: dateAt(year: 2026, month: 3, day: 15, hour: 23, minute: 59))
        let s4 = makeSession(date: dateAt(year: 2026, month: 3, day: 16, hour: 0, minute: 0))

        let result = filter.filterSessions(
            [s1, s2, s3, s4],
            on: dateAt(year: 2026, month: 3, day: 15),
            calendar: calendar
        )

        // s1, s2, s3 are on March 15; s4 is midnight of March 16
        #expect(result.count == 3)
    }

    // MARK: - Empty Range

    @Test("Empty range returns empty array")
    func emptyRange() {
        let _ = makeSession(date: dateAt(year: 2026, month: 3, day: 15))

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let result = filter.filterSessions(
            sessions,
            from: dateAt(year: 2026, month: 4, day: 1),
            to: dateAt(year: 2026, month: 4, day: 30),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test("No sessions at all returns empty array")
    func noSessions() {
        let result = filter.filterSessions(
            [],
            from: dateAt(year: 2026, month: 3, day: 1),
            to: dateAt(year: 2026, month: 3, day: 31),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    // MARK: - Midnight Boundary

    @Test("Session at exactly midnight attributed to that day")
    func midnightBoundary() {
        // Session at midnight of March 15
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 15, hour: 0, minute: 0))

        let result = filter.filterSessions(
            [s1],
            on: dateAt(year: 2026, month: 3, day: 15),
            calendar: calendar
        )
        #expect(result.count == 1)

        // Should NOT appear on March 14
        let prevDay = filter.filterSessions(
            [s1],
            on: dateAt(year: 2026, month: 3, day: 14),
            calendar: calendar
        )
        #expect(prevDay.isEmpty)
    }

    // MARK: - Timezone-Aware Filtering

    @Test("Timezone-aware date attribution uses calendar timezone")
    func timezoneAwareFiltering() {
        // Create calendars in different timezones
        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = TimeZone(identifier: "America/New_York")!

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        // March 15, 2026 11:00 PM Eastern = March 16, 2026 3:00 AM UTC
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 23
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")!
        let lateNightDate = Calendar(identifier: .gregorian).date(from: components)!

        let session = makeSession(date: lateNightDate)

        // In New York timezone, it's March 15
        let nyResult = filter.filterSessions(
            [session],
            on: dateAt(year: 2026, month: 3, day: 15),
            calendar: nyCal
        )
        #expect(nyResult.count == 1)

        // In UTC, it's March 16
        let utcMar15 = utcCal.startOfDay(for: lateNightDate)
        let utcMar16Start = utcCal.date(byAdding: .day, value: 1, to: utcMar15)!
        // The date is at 3AM UTC on March 16
        var utcComponents = DateComponents()
        utcComponents.year = 2026
        utcComponents.month = 3
        utcComponents.day = 16
        utcComponents.hour = 10
        let utcMar16 = utcCal.date(from: utcComponents)!

        let utcResult = filter.filterSessions(
            [session],
            on: utcMar16,
            calendar: utcCal
        )
        #expect(utcResult.count == 1)
    }

    // MARK: - Boundary Dates (Inclusive/Exclusive)

    @Test("Start date is inclusive, end date is exclusive")
    func startInclusiveEndExclusive() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 1, hour: 10))
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 31, hour: 10))

        let result = filter.filterSessions(
            [s1, s2],
            from: dateAt(year: 2026, month: 3, day: 1),
            to: dateAt(year: 2026, month: 3, day: 31),
            calendar: calendar
        )

        // March 1 is included (start inclusive), March 31 is excluded (end exclusive)
        #expect(result.count == 1)
        #expect(result[0].startTime == s1.startTime)
    }

    // MARK: - Group By Day

    @Test("Group by day correctly groups sessions")
    func groupByDay() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 1, hour: 9))
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 1, hour: 14))
        let s3 = makeSession(date: dateAt(year: 2026, month: 3, day: 2, hour: 10))

        let grouped = filter.groupByDay([s1, s2, s3], calendar: calendar)

        #expect(grouped.count == 2)

        let mar1Components = calendar.dateComponents([.year, .month, .day], from: dateAt(year: 2026, month: 3, day: 1))
        let mar2Components = calendar.dateComponents([.year, .month, .day], from: dateAt(year: 2026, month: 3, day: 2))

        #expect(grouped[mar1Components]?.count == 2)
        #expect(grouped[mar2Components]?.count == 1)
    }

    // MARK: - Daily Focus Times

    @Test("Daily focus times computes correctly for completed sessions")
    func dailyFocusTimes() {
        let s1 = makeSession(date: dateAt(year: 2026, month: 3, day: 1), duration: 1800)
        let s2 = makeSession(date: dateAt(year: 2026, month: 3, day: 1), duration: 1800)
        let s3 = makeSession(date: dateAt(year: 2026, month: 3, day: 2), duration: 3600)
        let s4 = makeSession(date: dateAt(year: 2026, month: 3, day: 2), duration: 7200, status: .abandoned)

        let dailyTimes = filter.dailyFocusTimes(
            [s1, s2, s3, s4],
            from: dateAt(year: 2026, month: 3, day: 1),
            to: dateAt(year: 2026, month: 3, day: 3),
            calendar: calendar
        )

        let mar1 = calendar.dateComponents([.year, .month, .day], from: dateAt(year: 2026, month: 3, day: 1))
        let mar2 = calendar.dateComponents([.year, .month, .day], from: dateAt(year: 2026, month: 3, day: 2))

        #expect(dailyTimes[mar1] == 3600.0) // 1800 + 1800
        #expect(dailyTimes[mar2] == 3600.0) // Only completed: 3600 (abandoned excluded)
    }
}

// MARK: - Historical Data Retention Tests

@Suite("HistoricalDataRetention Tests", .serialized)
@MainActor
struct HistoricalDataRetentionTests {

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

    private func makeSession(
        daysAgo: Int,
        duration: TimeInterval = 1800,
        status: SessionStatus = .completed
    ) -> DeepFocusSession {
        let startTime = calendar.date(
            byAdding: .day,
            value: -daysAgo,
            to: calendar.startOfDay(for: Date())
        )!.addingTimeInterval(36000) // 10 AM

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

    // MARK: - Sessions Retained Beyond 4 Weeks

    @Test("Sessions 30 days old are retained and queryable")
    func sessions30DaysOld() {
        let _ = makeSession(daysAgo: 30)

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let sessions = try! context.fetch(descriptor)
        #expect(sessions.count == 1)
    }

    @Test("Sessions 60 days old are retained and queryable")
    func sessions60DaysOld() {
        let _ = makeSession(daysAgo: 60)

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let sessions = try! context.fetch(descriptor)
        #expect(sessions.count == 1)
    }

    @Test("Sessions 90 days old are retained and queryable")
    func sessions90DaysOld() {
        let _ = makeSession(daysAgo: 90)

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let sessions = try! context.fetch(descriptor)
        #expect(sessions.count == 1)
    }

    @Test("Sessions 180 days old are retained and queryable")
    func sessions180DaysOld() {
        let _ = makeSession(daysAgo: 180)

        let descriptor = FetchDescriptor<DeepFocusSession>()
        let sessions = try! context.fetch(descriptor)
        #expect(sessions.count == 1)
    }

    // MARK: - Date Predicate Queries

    @Test("Old sessions queryable via date predicate")
    func datePredicateQuery() {
        let _ = makeSession(daysAgo: 30)
        let _ = makeSession(daysAgo: 60)
        let _ = makeSession(daysAgo: 90)
        let _ = makeSession(daysAgo: 180)
        let _ = makeSession(daysAgo: 0)

        // Query sessions older than 29 days
        let cutoff = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: Date())
        )!

        let predicate = #Predicate<DeepFocusSession> { session in
            session.startTime < cutoff
        }
        var descriptor = FetchDescriptor<DeepFocusSession>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.startTime)]

        let oldSessions = try! context.fetch(descriptor)
        #expect(oldSessions.count == 4) // 30, 60, 90, 180 days ago
    }

    @Test("Historical sessions used in weekly average calculations")
    func historicalWeeklyAverage() {
        let calculator = WeeklyAverageCalculator()

        // Create sessions 60 days ago (should be in a specific week)
        let date60DaysAgo = calendar.date(
            byAdding: .day,
            value: -60,
            to: calendar.startOfDay(for: Date())
        )!.addingTimeInterval(36000)

        let session = DeepFocusSession(
            startTime: date60DaysAgo,
            configuredDuration: 3600,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        let avg = calculator.weeklyAverage(
            sessions: [session],
            weekContaining: date60DaysAgo,
            calendar: calendar
        )
        #expect(avg == 3600.0)
    }

    @Test("Historical sessions used in monthly average calculations")
    func historicalMonthlyAverage() {
        let calculator = MonthlyAverageCalculator()

        // Create sessions 90 days ago
        let date90DaysAgo = calendar.date(
            byAdding: .day,
            value: -90,
            to: calendar.startOfDay(for: Date())
        )!.addingTimeInterval(36000)

        let components = calendar.dateComponents([.year, .month], from: date90DaysAgo)

        let session = DeepFocusSession(
            startTime: date90DaysAgo,
            configuredDuration: 5400,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        let avg = calculator.monthlyAverage(
            sessions: [session],
            year: components.year!,
            month: components.month!,
            calendar: calendar
        )
        #expect(avg == 5400.0)
    }
}

// MARK: - Midnight-Spanning and Long Session Tests

@Suite("MidnightSpanningAndLongSession Tests", .serialized)
@MainActor
struct MidnightSpanningAndLongSessionTests {

    let filter = DateRangeFilter()
    let weeklyCalc = WeeklyAverageCalculator()
    let monthlyCalc = MonthlyAverageCalculator()
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

    // MARK: - Midnight-Spanning Sessions

    @Test("Session starting at 11 PM spanning midnight is attributed to start date")
    func midnightSpanningStartDate() {
        // Session starts at 11 PM March 15, lasts 2 hours (ends 1 AM March 16)
        let startDate = dateAt(year: 2026, month: 3, day: 15, hour: 23, minute: 0)
        let session = DeepFocusSession(
            startTime: startDate,
            configuredDuration: 7200, // 2 hours
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        // Should appear on March 15
        let mar15Result = filter.filterSessions(
            [session],
            on: dateAt(year: 2026, month: 3, day: 15),
            calendar: calendar
        )
        #expect(mar15Result.count == 1)

        // Should NOT appear on March 16
        let mar16Result = filter.filterSessions(
            [session],
            on: dateAt(year: 2026, month: 3, day: 16),
            calendar: calendar
        )
        #expect(mar16Result.isEmpty)
    }

    @Test("Multiple midnight-spanning sessions attributed correctly")
    func multipleMidnightSpanning() {
        let s1 = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 3, day: 14, hour: 23),
            configuredDuration: 7200,
            remainingSeconds: 0,
            status: .completed
        )
        let s2 = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 3, day: 15, hour: 22),
            configuredDuration: 10800, // 3 hours
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(s1)
        context.insert(s2)
        try? context.save()

        // March 14 should have s1 only
        let mar14 = filter.filterSessions(
            [s1, s2],
            on: dateAt(year: 2026, month: 3, day: 14),
            calendar: calendar
        )
        #expect(mar14.count == 1)
        #expect(mar14[0].configuredDuration == 7200)

        // March 15 should have s2 only
        let mar15 = filter.filterSessions(
            [s1, s2],
            on: dateAt(year: 2026, month: 3, day: 15),
            calendar: calendar
        )
        #expect(mar15.count == 1)
        #expect(mar15[0].configuredDuration == 10800)
    }

    // MARK: - Very Long Sessions (8+ Hours)

    @Test("8-hour session stores and retrieves without overflow")
    func eightHourSession() {
        let duration: TimeInterval = 28800 // 8 hours = 28800 seconds
        let session = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 3, day: 15, hour: 8),
            configuredDuration: duration,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        let fetched = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(fetched.count == 1)
        #expect(fetched[0].configuredDuration == 28800)
    }

    @Test("12-hour session aggregates correctly in weekly average")
    func longSessionWeeklyAverage() {
        let duration: TimeInterval = 43200 // 12 hours
        let session = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 3, day: 31, hour: 6),
            configuredDuration: duration,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        let avg = weeklyCalc.weeklyAverage(
            sessions: [session],
            weekContaining: dateAt(year: 2026, month: 3, day: 31),
            calendar: calendar
        )
        #expect(avg == 43200.0)
    }

    @Test("24-hour session aggregates correctly in monthly average")
    func veryLongSessionMonthlyAverage() {
        let duration: TimeInterval = 86400 // 24 hours
        let session = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 3, day: 15, hour: 0),
            configuredDuration: duration,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        let avg = monthlyCalc.monthlyAverage(
            sessions: [session],
            year: 2026,
            month: 3,
            calendar: calendar
        )
        #expect(avg == 86400.0)
    }

    @Test("Multiple long sessions on different days aggregate without overflow")
    func multipleLongSessions() {
        let sessions = (1...5).map { day -> DeepFocusSession in
            let session = DeepFocusSession(
                startTime: dateAt(year: 2026, month: 3, day: day, hour: 8),
                configuredDuration: 28800, // 8 hours each
                remainingSeconds: 0,
                status: .completed
            )
            context.insert(session)
            return session
        }
        try? context.save()

        let avg = monthlyCalc.monthlyAverage(
            sessions: sessions,
            year: 2026,
            month: 3,
            calendar: calendar
        )
        // Total: 144000 / 5 days = 28800
        #expect(avg == 28800.0)
    }

    @Test("Midnight-spanning session counted in weekly average for start date's week")
    func midnightSpanningInWeeklyAverage() {
        // Session starts Saturday night, crosses into Sunday (new week with Sunday start)
        var sundayCal = calendar
        sundayCal.firstWeekday = 1 // Sunday

        // Saturday April 4 at 11 PM
        let session = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 4, day: 4, hour: 23),
            configuredDuration: 7200,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        // The session should be in the week containing April 4 (not April 5's week)
        let avg = weeklyCalc.weeklyAverage(
            sessions: [session],
            weekContaining: dateAt(year: 2026, month: 4, day: 4),
            calendar: sundayCal
        )
        #expect(avg == 7200.0)

        // The session should NOT be in the week of April 5 (next week)
        let nextWeekAvg = weeklyCalc.weeklyAverage(
            sessions: [session],
            weekContaining: dateAt(year: 2026, month: 4, day: 5),
            calendar: sundayCal
        )
        #expect(nextWeekAvg == 0)
    }

    @Test("Midnight-spanning session at month boundary attributed to start month")
    func midnightSpanningMonthBoundary() {
        // March 31 at 11 PM, 4-hour session (ends April 1 at 3 AM)
        let session = DeepFocusSession(
            startTime: dateAt(year: 2026, month: 3, day: 31, hour: 23),
            configuredDuration: 14400,
            remainingSeconds: 0,
            status: .completed
        )
        context.insert(session)
        try? context.save()

        // Should be in March's average
        let marchAvg = monthlyCalc.monthlyAverage(
            sessions: [session],
            year: 2026,
            month: 3,
            calendar: calendar
        )
        #expect(marchAvg == 14400.0)

        // Should NOT be in April's average
        let aprilAvg = monthlyCalc.monthlyAverage(
            sessions: [session],
            year: 2026,
            month: 4,
            calendar: calendar
        )
        #expect(aprilAvg == 0)
    }
}
