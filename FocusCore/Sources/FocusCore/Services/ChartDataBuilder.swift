import Foundation

// MARK: - BarChartDataPoint

/// A single data point for a daily usage bar chart.
public struct BarChartDataPoint: Equatable, Sendable, Identifiable {
    public var id: Date { date }
    /// The date this data point represents.
    public let date: Date
    /// The total focus time in seconds for this date.
    public let value: TimeInterval
    /// Formatted label for the date (e.g., "Mon", "3/15").
    public let label: String

    public init(date: Date, value: TimeInterval, label: String) {
        self.date = date
        self.value = value
        self.label = label
    }
}

// MARK: - LineChartDataPoint

/// A single data point for a weekly trend line chart.
public struct LineChartDataPoint: Equatable, Sendable, Identifiable {
    public var id: Date { date }
    /// The date (week start) this data point represents.
    public let date: Date
    /// The average daily focus time for this week in seconds.
    public let value: TimeInterval
    /// Formatted label for the week (e.g., "W1", "3/29").
    public let label: String

    public init(date: Date, value: TimeInterval, label: String) {
        self.date = date
        self.value = value
        self.label = label
    }
}

// MARK: - ChartDataBuilder

/// Produces data arrays for bar charts (daily usage) and line charts (weekly trends).
///
/// Handles:
/// - 1, 7, 30, 180+ data points
/// - Single data point renders correctly
/// - All-same values don't collapse Y-axis (applies minimum padding)
/// - Zero values rendered at baseline
/// - Large values scale correctly
/// - Only `.completed` sessions count toward usage
public struct ChartDataBuilder: Sendable {

    // MARK: - Configuration

    /// Minimum Y-axis padding factor when all values are the same.
    /// Prevents the Y-axis from collapsing to a single line.
    public static let sameValuePaddingFactor: Double = 0.2

    // MARK: - Initialization

    public init() {}

    // MARK: - Bar Chart Data (Daily Usage)

    /// Builds data points for a daily usage bar chart.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - startDate: The first date in the range (inclusive).
    ///   - endDate: The last date in the range (inclusive).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Array of `BarChartDataPoint`, one per day in the range.
    public func buildDailyBarChartData(
        sessions: [DeepFocusSession],
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> [BarChartDataPoint] {
        let completedSessions = sessions.filter { $0.status == .completed }
        let dateRangeFilter = DateRangeFilter()

        // Build a lookup of daily totals
        let grouped = dateRangeFilter.groupByDay(completedSessions, calendar: calendar)
        var dailyTotals: [DateComponents: TimeInterval] = [:]
        for (day, daySessions) in grouped {
            dailyTotals[day] = daySessions.reduce(0.0) { $0 + $1.configuredDuration }
        }

        // Generate one data point per day in the range
        var result: [BarChartDataPoint] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        let dateFormatter = DateFormatter()
        // For short ranges use day abbreviation, for longer use short date
        let totalDays = calendar.dateComponents([.day], from: currentDate, to: endDay).day ?? 0

        if totalDays <= 7 {
            dateFormatter.dateFormat = "EEE" // Mon, Tue, etc.
        } else if totalDays <= 31 {
            dateFormatter.dateFormat = "M/d" // 3/15
        } else {
            dateFormatter.dateFormat = "M/d" // 3/15
        }

        while currentDate <= endDay {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
            let value = dailyTotals[dayComponents] ?? 0

            result.append(BarChartDataPoint(
                date: currentDate,
                value: value,
                label: dateFormatter.string(from: currentDate)
            ))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDay
        }

        return result
    }

    /// Builds data points for a daily usage bar chart for the last N days.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status).
    ///   - days: Number of days to include (e.g., 7 for the past week).
    ///   - now: The current date (injectable for testing).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Array of `BarChartDataPoint`.
    public func buildDailyBarChartData(
        sessions: [DeepFocusSession],
        lastDays days: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BarChartDataPoint] {
        let endDate = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else {
            return []
        }
        return buildDailyBarChartData(
            sessions: sessions,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )
    }

    // MARK: - Line Chart Data (Weekly Trends)

    /// Builds data points for a weekly trend line chart.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - weeks: Number of weeks to include (e.g., 12 for the past 12 weeks).
    ///   - now: The current date (injectable for testing).
    ///   - calendar: Calendar for date calculations.
    /// - Returns: Array of `LineChartDataPoint`, one per week.
    public func buildWeeklyLineChartData(
        sessions: [DeepFocusSession],
        weeks: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [LineChartDataPoint] {
        let weeklyCalc = WeeklyAverageCalculator()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"

        var result: [LineChartDataPoint] = []

        for weekOffset in stride(from: -(weeks - 1), through: 0, by: 1) {
            guard let weekDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now) else {
                continue
            }

            let weekRange = weeklyCalc.weekDateRange(for: weekDate, calendar: calendar)
            let average = weeklyCalc.weeklyAverage(
                sessions: sessions,
                weekContaining: weekDate,
                calendar: calendar
            )

            result.append(LineChartDataPoint(
                date: weekRange.start,
                value: average,
                label: dateFormatter.string(from: weekRange.start)
            ))
        }

        return result
    }

    // MARK: - Y-Axis Range

    /// Computes Y-axis range with appropriate padding.
    ///
    /// When all values are the same, adds padding to prevent the axis from collapsing.
    /// Zero values are always rendered at the baseline (min starts at 0).
    ///
    /// - Parameter values: The data values.
    /// - Returns: Tuple of (min, max) for the Y-axis.
    public func yAxisRange(for values: [Double]) -> (min: Double, max: Double) {
        guard !values.isEmpty else {
            return (min: 0, max: 1)
        }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0

        // Always start at 0 for baseline
        let yMin: Double = 0

        if maxVal == 0 {
            // All zeros — show a small range
            return (min: 0, max: 1)
        }

        if minVal == maxVal {
            // All-same values: add padding to prevent collapse
            let padding = maxVal * Self.sameValuePaddingFactor
            return (min: yMin, max: maxVal + padding)
        }

        // Normal range — add small top padding for visual breathing room
        let range = maxVal - yMin
        let topPadding = range * 0.1
        return (min: yMin, max: maxVal + topPadding)
    }
}
