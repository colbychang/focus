import SwiftUI
import SwiftData
import FocusCore

// MARK: - StatsTabView

/// The Stats tab showing the analytics dashboard, session history,
/// charts, and DeviceActivityReport integration.
struct StatsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var dailyChartData: [BarChartDataPoint] = []
    @State private var weeklyChartData: [LineChartDataPoint] = []

    var body: some View {
        NavigationStack {
            StatsContentView(
                viewModel: viewModel,
                dailyChartData: dailyChartData,
                weeklyChartData: weeklyChartData
            )
            .navigationTitle("Stats")
        }
        .accessibilityIdentifier("StatsTabContent")
        .onAppear {
            if viewModel == nil {
                viewModel = DashboardViewModel(modelContext: modelContext)
            } else {
                viewModel?.refresh()
            }
            buildChartData()
        }
    }

    /// Builds chart data from the view model's sessions.
    private func buildChartData() {
        guard let viewModel else { return }
        let chartBuilder = ChartDataBuilder()

        dailyChartData = chartBuilder.buildDailyBarChartData(
            sessions: viewModel.allSessions,
            lastDays: 7
        )
        weeklyChartData = chartBuilder.buildWeeklyLineChartData(
            sessions: viewModel.allSessions,
            weeks: 12
        )
    }
}

// MARK: - StatsContentView

/// Inner content view with the dashboard, charts, history link, and screen time section.
struct StatsContentView: View {
    let viewModel: DashboardViewModel?
    let dailyChartData: [BarChartDataPoint]
    let weeklyChartData: [LineChartDataPoint]

    var body: some View {
        if let viewModel {
            ScrollView {
                VStack(spacing: 24) {
                    // Dashboard summary cards
                    DashboardView(viewModel: viewModel)
                        .padding(.horizontal)

                    // Charts section
                    if !viewModel.isEmpty {
                        AnalyticsChartsView(
                            dailyData: dailyChartData,
                            weeklyData: weeklyChartData
                        )
                    }

                    // Session History link
                    NavigationLink {
                        SessionHistoryView(sessions: viewModel.allSessions)
                            .navigationTitle("Session History")
                    } label: {
                        HStack {
                            Label("Session History", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                        )
                    }
                    .accessibilityIdentifier("SessionHistoryLink")
                    .padding(.horizontal)

                    // Screen Time section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Screen Time")
                            .font(.headline)
                            .padding(.horizontal)

                        DeviceActivityReportContainerView()
                            .frame(minHeight: 200)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        } else {
            ProgressView()
                .accessibilityIdentifier("StatsLoading")
        }
    }
}
