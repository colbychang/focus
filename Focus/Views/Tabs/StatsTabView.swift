import SwiftUI
import SwiftData
import FocusCore

// MARK: - StatsTabView

/// The Stats tab showing the analytics dashboard, session history,
/// and DeviceActivityReport integration.
struct StatsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            StatsContentView(viewModel: viewModel)
                .navigationTitle("Stats")
        }
        .accessibilityIdentifier("StatsTabContent")
        .onAppear {
            if viewModel == nil {
                viewModel = DashboardViewModel(modelContext: modelContext)
            } else {
                viewModel?.refresh()
            }
        }
    }
}

// MARK: - StatsContentView

/// Inner content view with the dashboard, history link, and screen time section.
struct StatsContentView: View {
    let viewModel: DashboardViewModel?

    var body: some View {
        if let viewModel {
            ScrollView {
                VStack(spacing: 24) {
                    // Dashboard summary cards
                    DashboardView(viewModel: viewModel)
                        .padding(.horizontal)

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
