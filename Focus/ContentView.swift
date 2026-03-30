import SwiftUI
import FocusCore

// MARK: - ContentView

/// Root view that manages the authorization flow and main tab navigation.
/// Shows authorization/onboarding when status is `.notDetermined`,
/// denied explanation when `.denied`, and the main tab bar when `.approved`.
struct ContentView: View {
    @Bindable var viewModel: AuthorizationViewModel

    var body: some View {
        switch viewModel.authorizationStatus {
        case .notDetermined:
            AuthorizationView(viewModel: viewModel)
        case .denied:
            AuthorizationDeniedView(viewModel: viewModel)
        case .approved:
            MainTabView()
        }
    }
}

// MARK: - MainTabView

/// The main tab bar with Focus, Deep Focus, Stats, and Settings tabs.
/// Focus tab is selected by default.
struct MainTabView: View {
    @State private var selectedTab: Tab = .focus

    enum Tab: String, CaseIterable {
        case focus
        case deepFocus
        case stats
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FocusTabView()
                .tag(Tab.focus)
                .tabItem {
                    Label("Focus", systemImage: "moon.fill")
                }

            DeepFocusTabView()
                .tag(Tab.deepFocus)
                .tabItem {
                    Label("Deep Focus", systemImage: "target")
                }

            StatsTabView()
                .tag(Tab.stats)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            SettingsTabView()
                .tag(Tab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accessibilityIdentifier("MainTabView")
    }
}
