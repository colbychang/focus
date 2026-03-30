import SwiftUI

// MARK: - DeepFocusTabView

/// Placeholder view for the Deep Focus tab.
struct DeepFocusTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                Text("Deep Focus")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Start a deep focus session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Deep Focus")
        }
        .accessibilityIdentifier("DeepFocusTabContent")
    }
}
