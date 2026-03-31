import SwiftUI

// MARK: - SettingsTabView

/// Settings tab with configuration options.
/// Includes navigation to the grayscale setup guide.
struct SettingsTabView: View {
    @State private var showGrayscaleGuide = false

    var body: some View {
        NavigationStack {
            List {
                // Focus Tools section
                Section {
                    Button {
                        showGrayscaleGuide = true
                    } label: {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.title3)
                                .foregroundStyle(.gray)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grayscale Mode Guide")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Set up the accessibility shortcut")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("GrayscaleGuideButton")
                } header: {
                    Text("Focus Tools")
                } footer: {
                    Text("Grayscale mode makes your phone less visually stimulating during focus sessions.")
                }
            }
            .navigationTitle("Settings")
        }
        .accessibilityIdentifier("SettingsTabContent")
        .sheet(isPresented: $showGrayscaleGuide) {
            GrayscaleGuideView()
        }
    }
}
