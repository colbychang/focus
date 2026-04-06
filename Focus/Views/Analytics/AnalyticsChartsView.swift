import SwiftUI
import Charts
import FocusCore

// MARK: - DailyUsageBarChart

/// Bar chart displaying daily focus time.
/// Uses SwiftUI Charts with BarMark for each day's total focus duration.
struct DailyUsageBarChart: View {
    let dataPoints: [BarChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Usage")
                .font(.headline)
                .accessibilityIdentifier("DailyUsageChartTitle")

            if dataPoints.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .accessibilityIdentifier("DailyUsageEmptyState")
            } else {
                let yRange = ChartDataBuilder().yAxisRange(for: dataPoints.map { $0.value })

                Chart(dataPoints) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Focus Time", point.value / 60.0) // Convert to minutes
                    )
                    .foregroundStyle(.blue.gradient)
                    .accessibilityLabel("\(point.label): \(Self.formatMinutes(point.value))")
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if dataPoints.count <= 14 {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        } else {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text("\(Int(mins))m")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(yRange.max / 60.0))
                .frame(minHeight: 200)
                .accessibilityIdentifier("DailyUsageBarChart")
            }
        }
    }

    /// Formats seconds into a human-readable minutes string.
    private static func formatMinutes(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(totalMinutes)m"
    }
}

// MARK: - WeeklyTrendLineChart

/// Line chart displaying weekly average focus time trend.
/// Uses SwiftUI Charts with LineMark for each week's average.
struct WeeklyTrendLineChart: View {
    let dataPoints: [LineChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Trend")
                .font(.headline)
                .accessibilityIdentifier("WeeklyTrendChartTitle")

            if dataPoints.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .accessibilityIdentifier("WeeklyTrendEmptyState")
            } else {
                let yRange = ChartDataBuilder().yAxisRange(for: dataPoints.map { $0.value })

                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Week", point.date, unit: .weekOfYear),
                        y: .value("Avg Focus Time", point.value / 60.0) // Convert to minutes
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle())
                    .symbolSize(30)
                    .accessibilityLabel("\(point.label): \(Self.formatMinutes(point.value))")

                    AreaMark(
                        x: .value("Week", point.date, unit: .weekOfYear),
                        y: .value("Avg Focus Time", point.value / 60.0)
                    )
                    .foregroundStyle(.green.opacity(0.1))
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text("\(Int(mins))m")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(yRange.max / 60.0))
                .frame(minHeight: 200)
                .accessibilityIdentifier("WeeklyTrendLineChart")
            }
        }
    }

    /// Formats seconds into a human-readable minutes string.
    private static func formatMinutes(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(totalMinutes)m"
    }
}

// MARK: - AnalyticsChartsView

/// Container view for both charts: daily usage bar chart and weekly trend line chart.
struct AnalyticsChartsView: View {
    let dailyData: [BarChartDataPoint]
    let weeklyData: [LineChartDataPoint]

    var body: some View {
        VStack(spacing: 24) {
            DailyUsageBarChart(dataPoints: dailyData)
                .padding(.horizontal)

            WeeklyTrendLineChart(dataPoints: weeklyData)
                .padding(.horizontal)
        }
        .accessibilityIdentifier("AnalyticsChartsContainer")
    }
}
