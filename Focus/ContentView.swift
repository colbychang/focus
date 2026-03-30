import SwiftUI
import FocusCore

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Focus")
                .accessibilityIdentifier("FocusTab")
                .tabItem {
                    Label("Focus", systemImage: "moon.fill")
                }

            Text("Deep Focus")
                .accessibilityIdentifier("DeepFocusTab")
                .tabItem {
                    Label("Deep Focus", systemImage: "target")
                }

            Text("Stats")
                .accessibilityIdentifier("StatsTab")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            Text("Settings")
                .accessibilityIdentifier("SettingsTab")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
