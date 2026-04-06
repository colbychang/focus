import SwiftUI
import FocusCore

// MARK: - DashboardView

/// Displays summary cards for total focus time, sessions completed, and current streak.
/// Shows an empty state with instructional message when no sessions exist.
struct DashboardView: View {
    let viewModel: DashboardViewModel

    var body: some View {
        if viewModel.isEmpty {
            DashboardEmptyStateView()
        } else {
            DashboardCardsView(viewModel: viewModel)
        }
    }
}

// MARK: - DashboardCardsView

/// Displays the three summary cards in a horizontal layout.
struct DashboardCardsView: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                SummaryCardView(
                    title: "Total Focus Time",
                    value: DashboardViewModel.formatDuration(viewModel.totalFocusTime),
                    systemImage: "clock.fill",
                    color: .blue,
                    accessibilityID: "TotalFocusTimeCard"
                )

                SummaryCardView(
                    title: "Sessions",
                    value: "\(viewModel.sessionsCompleted)",
                    systemImage: "checkmark.circle.fill",
                    color: .green,
                    accessibilityID: "SessionsCompletedCard"
                )
            }

            SummaryCardView(
                title: "Current Streak",
                value: "\(viewModel.currentStreak) day\(viewModel.currentStreak == 1 ? "" : "s")",
                systemImage: "flame.fill",
                color: .orange,
                accessibilityID: "CurrentStreakCard"
            )
        }
        .accessibilityIdentifier("DashboardCards")
    }
}

// MARK: - SummaryCardView

/// A single summary card with title, value, icon, and color.
struct SummaryCardView: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("\(accessibilityID)_Value")

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(accessibilityID)_Title")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - DashboardEmptyStateView

/// Empty state view shown when there are no sessions yet.
struct DashboardEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No sessions yet")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityIdentifier("EmptyStateTitle")

            Text("Complete a focus session to see your statistics here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier("EmptyStateMessage")
        }
        .accessibilityIdentifier("DashboardEmptyState")
    }
}
