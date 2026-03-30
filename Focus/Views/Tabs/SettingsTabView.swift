import SwiftUI

// MARK: - SettingsTabView

/// Placeholder view for the Settings tab.
struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "gear")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                Text("Settings")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Configure your preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
        }
        .accessibilityIdentifier("SettingsTabContent")
    }
}
