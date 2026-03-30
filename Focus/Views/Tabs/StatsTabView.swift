import SwiftUI

// MARK: - StatsTabView

/// Placeholder view for the Stats tab.
struct StatsTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("Stats")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("View your screen time analytics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Stats")
        }
        .accessibilityIdentifier("StatsTabContent")
    }
}
