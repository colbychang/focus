import Testing
import Foundation
import SwiftData
@testable import FocusCore
@testable import Focus

// MARK: - TrendDetector Tests

@Suite("TrendDetector Tests", .serialized)
struct TrendDetectorTests {

    let detector = TrendDetector()

    // MARK: - Undetermined (Insufficient Data)

    @Test("Fewer than 7 data points returns .undetermined")
    func insufficientData() {
        let result = detector.analyze([1, 2, 3, 4, 5, 6])
        #expect(result.trend == .undetermined)
        #expect(result.spikes.isEmpty)
    }

    @Test("Empty data returns .undetermined")
    func emptyData() {
        let result = detector.analyze([])
        #expect(result.trend == .undetermined)
    }

    @Test("Single data point returns .undetermined")
    func singlePoint() {
        let result = detector.analyze([42])
        #expect(result.trend == .undetermined)
    }

    @Test("Exactly 6 data points returns .undetermined")
    func sixPoints() {
        let result = detector.analyze([1, 2, 3, 4, 5, 6])
        #expect(result.trend == .undetermined)
    }

    // MARK: - Increasing Trend

    @Test("Steadily increasing data classified as .increasing")
    func increasingTrend() {
        // 7 data points, all increasing: 100, 200, 300, 400, 500, 600, 700
        let data = (1...7).map { Double($0) * 100 }
        let result = detector.analyze(data)
        #expect(result.trend == .increasing)
    }

    @Test("Mostly increasing data classified as .increasing")
    func mostlyIncreasing() {
        // 10 points, 7 increases, 2 decreases → 70% increasing
        let data: [Double] = [100, 200, 150, 300, 400, 350, 500, 600, 700, 800]
        let result = detector.analyze(data)
        #expect(result.trend == .increasing)
    }

    @Test("Gradual increase over 14 points classified as .increasing")
    func gradualIncrease() {
        let data = (0..<14).map { Double($0) * 10 + 100 }
        let result = detector.analyze(data)
        #expect(result.trend == .increasing)
    }

    // MARK: - Decreasing Trend

    @Test("Steadily decreasing data classified as .decreasing")
    func decreasingTrend() {
        let data: [Double] = [700, 600, 500, 400, 300, 200, 100]
        let result = detector.analyze(data)
        #expect(result.trend == .decreasing)
    }

    @Test("Mostly decreasing data classified as .decreasing")
    func mostlyDecreasing() {
        // 10 points, 7 decreases, 2 increases → 70% decreasing
        let data: [Double] = [800, 700, 750, 600, 500, 550, 400, 300, 200, 100]
        let result = detector.analyze(data)
        #expect(result.trend == .decreasing)
    }

    // MARK: - Stable Trend

    @Test("Flat data classified as .stable")
    func flatData() {
        let data: [Double] = [100, 100, 100, 100, 100, 100, 100]
        let result = detector.analyze(data)
        #expect(result.trend == .stable)
    }

    @Test("Data with normal variance classified as .stable")
    func normalVariance() {
        // Slight oscillation — no dominant direction
        let data: [Double] = [100, 110, 95, 105, 100, 108, 97, 103, 99, 106]
        let result = detector.analyze(data)
        #expect(result.trend == .stable)
    }

    @Test("Perfectly alternating data classified as .stable")
    func alternatingData() {
        let data: [Double] = [100, 200, 100, 200, 100, 200, 100]
        let result = detector.analyze(data)
        #expect(result.trend == .stable)
    }

    // MARK: - Spike Detection

    @Test("Spike detected when value exceeds 2x moving average")
    func spikeDetected() {
        // 7 baseline values of 100, then a spike of 300
        var data = Array(repeating: 100.0, count: 7)
        data.append(300) // 3x the average — should be a spike
        let result = detector.analyze(data)
        #expect(result.spikes.count == 1)
        #expect(result.spikes[0].index == 7)
        #expect(result.spikes[0].value == 300)
        #expect(result.spikes[0].movingAverage == 100)
        #expect(result.spikes[0].ratio == 3.0)
    }

    @Test("Multiple spikes detected")
    func multipleSpikes() {
        // Baseline of 100, two spikes
        var data = Array(repeating: 100.0, count: 7)
        data.append(500) // spike at index 7
        data.append(100) // normal
        data.append(100)
        data.append(100)
        data.append(100)
        data.append(100)
        data.append(100)
        data.append(400) // spike at index 14
        let result = detector.analyze(data)
        #expect(result.spikes.count >= 2)
    }

    @Test("Value exactly at 2x threshold is not a spike (must exceed)")
    func exactlyAt2x() {
        var data = Array(repeating: 100.0, count: 7)
        data.append(200) // Exactly 2x — should NOT be a spike (needs to EXCEED 2x)
        let result = detector.analyze(data)
        #expect(result.spikes.isEmpty)
    }

    @Test("Value just above 2x threshold is a spike")
    func justAbove2x() {
        var data = Array(repeating: 100.0, count: 7)
        data.append(201) // Just above 2x
        let result = detector.analyze(data)
        #expect(result.spikes.count == 1)
    }

    // MARK: - False Positive Avoidance

    @Test("No false positives for normal variance in stable data")
    func noFalsePositivesStable() {
        // Slight fluctuations, no spikes expected
        let data: [Double] = [100, 105, 98, 110, 95, 102, 108, 103, 97, 106, 101, 99, 104, 107]
        let result = detector.analyze(data)
        #expect(result.spikes.isEmpty)
    }

    @Test("No false positives for gradually increasing data")
    func noFalsePositivesGradual() {
        // Gradual increase — each value is only slightly higher, not 2x
        let data = (0..<14).map { 100.0 + Double($0) * 10 }
        let result = detector.analyze(data)
        #expect(result.spikes.isEmpty)
    }

    @Test("No spike detected when moving average is zero (all preceding values zero)")
    func zeroMovingAverage() {
        var data = Array(repeating: 0.0, count: 7)
        data.append(100) // Non-zero value after zeros — no spike (division by zero guard)
        let result = detector.analyze(data)
        #expect(result.spikes.isEmpty)
    }

    // MARK: - Configurable Thresholds

    @Test("Custom minimum data points threshold")
    func customMinDataPoints() {
        let config = TrendDetectorConfig(minimumDataPoints: 3)
        let customDetector = TrendDetector(config: config)
        let result = customDetector.analyze([100, 200, 300])
        #expect(result.trend == .increasing)
    }

    @Test("Custom spike threshold (3x)")
    func customSpikeThreshold() {
        let config = TrendDetectorConfig(spikeThreshold: 3.0)
        let customDetector = TrendDetector(config: config)

        var data = Array(repeating: 100.0, count: 7)
        data.append(250) // 2.5x — below 3x threshold
        let result = customDetector.analyze(data)
        #expect(result.spikes.isEmpty) // Not a spike with 3x threshold
    }

    @Test("Custom increasing threshold (0.8)")
    func customIncreasingThreshold() {
        let config = TrendDetectorConfig(increasingThreshold: 0.8)
        let customDetector = TrendDetector(config: config)

        // 10 points, 9 transitions: 7 increases, 2 decreases = 7/9 ≈ 77.7% (below 80%)
        let data: [Double] = [100, 200, 150, 250, 200, 300, 400, 500, 600, 700]
        let result = customDetector.analyze(data)
        // With 80% threshold: 7/9 = 77.7% increases, should be stable
        #expect(result.trend == .stable)
    }

    // MARK: - Exactly 7 Data Points (Minimum)

    @Test("Exactly 7 data points works correctly")
    func exactlySevenPoints() {
        let increasing: [Double] = [100, 200, 300, 400, 500, 600, 700]
        let result = detector.analyze(increasing)
        #expect(result.trend == .increasing)
    }

    // MARK: - Spike Detection with Trend

    @Test("Spike detected within an overall increasing trend")
    func spikeWithIncrease() {
        // Gradual increase with a sudden spike
        let data: [Double] = [100, 110, 120, 130, 140, 150, 160, 500, 180, 190]
        let result = detector.analyze(data)
        #expect(result.trend == .increasing)
        #expect(!result.spikes.isEmpty)
    }
}

// MARK: - CategoryAggregator Tests

@Suite("CategoryAggregator Tests", .serialized)
@MainActor
struct CategoryAggregatorTests {

    let aggregator = CategoryAggregator()
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - Helpers

    private func makeFocusMode(name: String) -> FocusMode {
        let mode = FocusMode(name: name)
        context.insert(mode)
        try? context.save()
        return mode
    }

    private func makeSession(
        duration: TimeInterval = 1800,
        status: SessionStatus = .completed,
        focusMode: FocusMode? = nil
    ) -> DeepFocusSession {
        let session = DeepFocusSession(
            configuredDuration: duration,
            remainingSeconds: status == .completed ? 0 : duration,
            status: status,
            focusMode: focusMode
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - User-Defined Groups

    @Test("Sessions grouped under their focus mode names")
    func userDefinedGroups() {
        let workMode = makeFocusMode(name: "Work")
        let studyMode = makeFocusMode(name: "Study")

        let s1 = makeSession(duration: 1800, focusMode: workMode)
        let s2 = makeSession(duration: 3600, focusMode: workMode)
        let s3 = makeSession(duration: 2400, focusMode: studyMode)

        let result = aggregator.aggregate(sessions: [s1, s2, s3])

        let workUsage = result.categories.first { $0.categoryName == "Work" }
        let studyUsage = result.categories.first { $0.categoryName == "Study" }

        #expect(workUsage != nil)
        #expect(workUsage!.totalDuration == 5400)
        #expect(workUsage!.sessionCount == 2)
        #expect(studyUsage != nil)
        #expect(studyUsage!.totalDuration == 2400)
        #expect(studyUsage!.sessionCount == 1)
    }

    // MARK: - Uncategorized

    @Test("Sessions without focus mode go to Uncategorized")
    func uncategorizedSessions() {
        let s1 = makeSession(duration: 1800) // No focus mode
        let s2 = makeSession(duration: 3600) // No focus mode

        let result = aggregator.aggregate(sessions: [s1, s2])

        #expect(result.uncategorized != nil)
        #expect(result.uncategorized!.totalDuration == 5400)
        #expect(result.uncategorized!.sessionCount == 2)
    }

    @Test("Mixed sessions: some categorized, some uncategorized")
    func mixedSessions() {
        let workMode = makeFocusMode(name: "Work")

        let s1 = makeSession(duration: 1800, focusMode: workMode)
        let s2 = makeSession(duration: 3600) // Uncategorized

        let result = aggregator.aggregate(sessions: [s1, s2])

        let workUsage = result.categories.first { $0.categoryName == "Work" }
        #expect(workUsage!.totalDuration == 1800)

        #expect(result.uncategorized != nil)
        #expect(result.uncategorized!.totalDuration == 3600)
    }

    // MARK: - Sum Consistency

    @Test("All category totals sum to grand total")
    func sumConsistency() {
        let workMode = makeFocusMode(name: "Work")
        let studyMode = makeFocusMode(name: "Study")

        let s1 = makeSession(duration: 1800, focusMode: workMode)
        let s2 = makeSession(duration: 3600, focusMode: studyMode)
        let s3 = makeSession(duration: 2400) // Uncategorized
        let s4 = makeSession(duration: 900, focusMode: workMode)

        let result = aggregator.aggregate(sessions: [s1, s2, s3, s4])

        let categorySum = result.categories.reduce(0.0) { $0 + $1.totalDuration }
        #expect(categorySum == result.grandTotal)
        #expect(result.grandTotal == 8700) // 1800 + 3600 + 2400 + 900
    }

    @Test("Sum consistency with many categories")
    func sumConsistencyManyCategories() {
        let modes = ["Work", "Study", "Reading", "Exercise", "Meditation"].map { makeFocusMode(name: $0) }

        var sessions: [DeepFocusSession] = []
        for (i, mode) in modes.enumerated() {
            sessions.append(makeSession(duration: Double((i + 1) * 600), focusMode: mode))
        }
        // Also add uncategorized
        sessions.append(makeSession(duration: 1200))

        let result = aggregator.aggregate(sessions: sessions)

        let categorySum = result.categories.reduce(0.0) { $0 + $1.totalDuration }
        #expect(categorySum == result.grandTotal)
    }

    // MARK: - Abandoned Sessions Excluded

    @Test("Abandoned sessions excluded from aggregation")
    func abandonedExcluded() {
        let workMode = makeFocusMode(name: "Work")

        let s1 = makeSession(duration: 1800, status: .completed, focusMode: workMode)
        let s2 = makeSession(duration: 3600, status: .abandoned, focusMode: workMode)

        let result = aggregator.aggregate(sessions: [s1, s2])

        let workUsage = result.categories.first { $0.categoryName == "Work" }
        #expect(workUsage!.totalDuration == 1800) // Only completed
        #expect(workUsage!.sessionCount == 1)
        #expect(result.grandTotal == 1800)
    }

    // MARK: - Empty State

    @Test("No sessions returns empty result")
    func emptyState() {
        let result = aggregator.aggregate(sessions: [])
        #expect(result.categories.isEmpty)
        #expect(result.grandTotal == 0)
    }

    @Test("Only abandoned sessions returns empty result")
    func onlyAbandoned() {
        let s1 = makeSession(duration: 1800, status: .abandoned)
        let result = aggregator.aggregate(sessions: [s1])
        #expect(result.categories.isEmpty)
        #expect(result.grandTotal == 0)
    }
}

// MARK: - ModeTypeBreakdown Tests

@Suite("ModeTypeBreakdown Tests", .serialized)
@MainActor
struct ModeTypeBreakdownTests {

    let breakdown = ModeTypeBreakdown()
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let schema = Schema(AppSchemaV2.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - Helpers

    private func makeFocusMode(name: String) -> FocusMode {
        let mode = FocusMode(name: name)
        context.insert(mode)
        try? context.save()
        return mode
    }

    private func makeSession(
        duration: TimeInterval = 1800,
        status: SessionStatus = .completed,
        focusMode: FocusMode? = nil
    ) -> DeepFocusSession {
        let session = DeepFocusSession(
            configuredDuration: duration,
            remainingSeconds: status == .completed ? 0 : duration,
            status: status,
            focusMode: focusMode
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Basic Breakdown

    @Test("Sessions grouped by mode type")
    func basicBreakdown() {
        let workMode = makeFocusMode(name: "Work")
        let studyMode = makeFocusMode(name: "Study")

        let s1 = makeSession(duration: 1800, focusMode: workMode)
        let s2 = makeSession(duration: 3600, focusMode: studyMode)
        let s3 = makeSession(duration: 2400) // Deep Focus (no mode)

        let result = breakdown.compute(sessions: [s1, s2, s3])

        #expect(result.usage(for: "Work")!.totalDuration == 1800)
        #expect(result.usage(for: "Study")!.totalDuration == 3600)
        #expect(result.usage(for: "Deep Focus")!.totalDuration == 2400)
    }

    // MARK: - Sum Consistency

    @Test("Per-type totals sum to grand total")
    func sumConsistency() {
        let workMode = makeFocusMode(name: "Work")
        let studyMode = makeFocusMode(name: "Study")

        let s1 = makeSession(duration: 1800, focusMode: workMode)
        let s2 = makeSession(duration: 3600, focusMode: studyMode)
        let s3 = makeSession(duration: 2400)

        let result = breakdown.compute(sessions: [s1, s2, s3])

        let typeSum = result.modeTypes.reduce(0.0) { $0 + $1.totalDuration }
        #expect(typeSum == result.grandTotal)
        #expect(result.grandTotal == 7800)
    }

    // MARK: - Custom Mode Types

    @Test("Custom user-created mode types included")
    func customModeTypes() {
        let customMode = makeFocusMode(name: "Meditation")

        let s1 = makeSession(duration: 3600, focusMode: customMode)
        let result = breakdown.compute(sessions: [s1])

        #expect(result.usage(for: "Meditation") != nil)
        #expect(result.usage(for: "Meditation")!.totalDuration == 3600)
    }

    // MARK: - Zero Session Modes

    @Test("Modes with zero sessions handled via computeWithAllModes")
    func zeroSessionModes() {
        let workMode = makeFocusMode(name: "Work")
        let s1 = makeSession(duration: 1800, focusMode: workMode)

        let result = breakdown.computeWithAllModes(
            sessions: [s1],
            allModeNames: ["Work", "Study", "Reading"]
        )

        // Work has sessions
        #expect(result.usage(for: "Work")!.totalDuration == 1800)
        #expect(result.usage(for: "Work")!.sessionCount == 1)

        // Study and Reading have zero sessions
        #expect(result.usage(for: "Study")!.totalDuration == 0)
        #expect(result.usage(for: "Study")!.sessionCount == 0)
        #expect(result.usage(for: "Reading")!.totalDuration == 0)
        #expect(result.usage(for: "Reading")!.sessionCount == 0)

        // Deep Focus also included with zero
        #expect(result.usage(for: "Deep Focus")!.totalDuration == 0)

        // Sum still consistent
        let typeSum = result.modeTypes.reduce(0.0) { $0 + $1.totalDuration }
        #expect(typeSum == result.grandTotal)
    }

    // MARK: - Abandoned Sessions Excluded

    @Test("Abandoned sessions excluded from breakdown")
    func abandonedExcluded() {
        let workMode = makeFocusMode(name: "Work")

        let s1 = makeSession(duration: 1800, status: .completed, focusMode: workMode)
        let s2 = makeSession(duration: 3600, status: .abandoned, focusMode: workMode)

        let result = breakdown.compute(sessions: [s1, s2])

        #expect(result.usage(for: "Work")!.totalDuration == 1800)
        #expect(result.usage(for: "Work")!.sessionCount == 1)
        #expect(result.grandTotal == 1800)
    }

    // MARK: - Empty State

    @Test("No sessions returns empty breakdown")
    func emptyState() {
        let result = breakdown.compute(sessions: [])
        #expect(result.modeTypes.isEmpty)
        #expect(result.grandTotal == 0)
    }

    // MARK: - Sessions Without Focus Mode

    @Test("Sessions without focus mode labeled as Deep Focus")
    func deepFocusLabel() {
        let s1 = makeSession(duration: 1800)
        let s2 = makeSession(duration: 3600)

        let result = breakdown.compute(sessions: [s1, s2])

        #expect(result.modeTypes.count == 1)
        #expect(result.usage(for: "Deep Focus")!.totalDuration == 5400)
        #expect(result.usage(for: "Deep Focus")!.sessionCount == 2)
    }

    // MARK: - Multiple Sessions Per Mode

    @Test("Multiple sessions per mode aggregate correctly")
    func multipleSessionsPerMode() {
        let workMode = makeFocusMode(name: "Work")

        let s1 = makeSession(duration: 1800, focusMode: workMode)
        let s2 = makeSession(duration: 3600, focusMode: workMode)
        let s3 = makeSession(duration: 900, focusMode: workMode)

        let result = breakdown.compute(sessions: [s1, s2, s3])

        #expect(result.usage(for: "Work")!.totalDuration == 6300)
        #expect(result.usage(for: "Work")!.sessionCount == 3)
    }
}

// MARK: - DeepFocusStatsCalculator Tests

@Suite("DeepFocusStatsCalculator Tests", .serialized)
@MainActor
struct DeepFocusStatsCalculatorTests {

    let calculator = DeepFocusStatsCalculator()
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
        duration: TimeInterval = 1800,
        remainingSeconds: TimeInterval? = nil,
        status: SessionStatus = .completed,
        bypassCount: Int = 0,
        breakCount: Int = 0
    ) -> DeepFocusSession {
        let remaining = remainingSeconds ?? (status == .completed ? 0 : duration)
        let session = DeepFocusSession(
            configuredDuration: duration,
            remainingSeconds: remaining,
            status: status,
            bypassCount: bypassCount,
            breakCount: breakCount
        )
        context.insert(session)
        try? context.save()
        return session
    }

    // MARK: - Sessions Started

    @Test("Sessions started counts all non-idle sessions")
    func sessionsStarted() {
        let _ = makeSession(status: .completed)
        let _ = makeSession(status: .abandoned)
        let _ = makeSession(status: .active)
        let _ = makeSession(status: .idle) // Should NOT count

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.sessionsStarted == 3)
    }

    // MARK: - Sessions Completed

    @Test("Sessions completed counts only completed sessions")
    func sessionsCompleted() {
        let _ = makeSession(status: .completed)
        let _ = makeSession(status: .completed)
        let _ = makeSession(status: .abandoned)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.sessionsCompleted == 2)
    }

    // MARK: - Total Bypasses

    @Test("Total bypasses sums bypass counts across all started sessions")
    func totalBypasses() {
        let _ = makeSession(status: .completed, bypassCount: 3)
        let _ = makeSession(status: .abandoned, bypassCount: 2)
        let _ = makeSession(status: .completed, bypassCount: 1)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.totalBypasses == 6)
    }

    // MARK: - Total Breaks

    @Test("Total breaks sums break counts across all started sessions")
    func totalBreaks() {
        let _ = makeSession(status: .completed, breakCount: 2)
        let _ = makeSession(status: .abandoned, breakCount: 1)
        let _ = makeSession(status: .completed, breakCount: 3)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.totalBreaks == 6)
    }

    // MARK: - Total Focus Time

    @Test("Total focus time includes only completed sessions")
    func totalFocusTimeCompletedOnly() {
        let _ = makeSession(duration: 1800, status: .completed)
        let _ = makeSession(duration: 3600, status: .completed)
        let _ = makeSession(duration: 900, status: .abandoned) // Excluded

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.totalFocusTime == 5400) // 1800 + 3600
    }

    @Test("Abandoned sessions elapsed time excluded from focus time")
    func abandonedExcluded() {
        // Abandoned session that ran for 600 out of 1800 seconds
        let _ = makeSession(duration: 1800, remainingSeconds: 1200, status: .abandoned)
        // Completed session
        let _ = makeSession(duration: 3600, status: .completed)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        // Only the completed session's duration counts
        #expect(stats.totalFocusTime == 3600)
    }

    @Test("All abandoned sessions give zero focus time")
    func allAbandonedZeroFocusTime() {
        let _ = makeSession(duration: 1800, status: .abandoned)
        let _ = makeSession(duration: 3600, status: .abandoned)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.totalFocusTime == 0)
    }

    // MARK: - Completion Rate

    @Test("Completion rate computed correctly")
    func completionRate() {
        let _ = makeSession(status: .completed)
        let _ = makeSession(status: .completed)
        let _ = makeSession(status: .abandoned)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        // 2 completed / 3 started ≈ 0.6667
        #expect(abs(stats.completionRate - 2.0 / 3.0) < 0.001)
    }

    @Test("Completion rate is 1.0 when all sessions completed")
    func completionRateAllComplete() {
        let _ = makeSession(status: .completed)
        let _ = makeSession(status: .completed)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.completionRate == 1.0)
    }

    @Test("Completion rate is 0.0 when all sessions abandoned")
    func completionRateAllAbandoned() {
        let _ = makeSession(status: .abandoned)
        let _ = makeSession(status: .abandoned)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.completionRate == 0.0)
    }

    @Test("Completion rate is 0.0 when no sessions")
    func completionRateEmpty() {
        let stats = calculator.calculate(sessions: [])
        #expect(stats.completionRate == 0.0)
    }

    // MARK: - Empty State

    @Test("Empty sessions gives all zeros")
    func emptyState() {
        let stats = calculator.calculate(sessions: [])

        #expect(stats.sessionsStarted == 0)
        #expect(stats.sessionsCompleted == 0)
        #expect(stats.totalBypasses == 0)
        #expect(stats.totalBreaks == 0)
        #expect(stats.totalFocusTime == 0)
        #expect(stats.completionRate == 0)
    }

    // MARK: - Mixed Statuses

    @Test("Mixed session statuses computed correctly")
    func mixedStatuses() {
        let _ = makeSession(duration: 1800, status: .completed, bypassCount: 1, breakCount: 2)
        let _ = makeSession(duration: 3600, status: .completed, bypassCount: 0, breakCount: 1)
        let _ = makeSession(duration: 900, status: .abandoned, bypassCount: 2, breakCount: 0)
        let _ = makeSession(duration: 1200, status: .active, bypassCount: 1, breakCount: 0)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.sessionsStarted == 4) // completed, completed, abandoned, active
        #expect(stats.sessionsCompleted == 2)
        #expect(stats.totalBypasses == 4) // 1 + 0 + 2 + 1
        #expect(stats.totalBreaks == 3) // 2 + 1 + 0 + 0
        #expect(stats.totalFocusTime == 5400) // 1800 + 3600 (completed only)
        #expect(stats.completionRate == 0.5) // 2 / 4
    }

    // MARK: - Idle Sessions Excluded

    @Test("Idle sessions not counted in any metric")
    func idleSessionsExcluded() {
        let _ = makeSession(duration: 1800, status: .idle, bypassCount: 0, breakCount: 0)
        let _ = makeSession(duration: 3600, status: .completed, bypassCount: 1, breakCount: 1)

        let sessions = try! context.fetch(FetchDescriptor<DeepFocusSession>())
        let stats = calculator.calculate(sessions: sessions)

        #expect(stats.sessionsStarted == 1) // Only completed, not idle
        #expect(stats.sessionsCompleted == 1)
        #expect(stats.totalBypasses == 1)
        #expect(stats.totalBreaks == 1)
        #expect(stats.totalFocusTime == 3600)
        #expect(stats.completionRate == 1.0)
    }
}
