import SwiftUI

// MARK: - FocusTabView

/// Placeholder view for the Focus tab.
struct FocusTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                Text("Focus")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Manage your focus modes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Focus")
        }
        .accessibilityIdentifier("FocusTabContent")
    }
}
