import SwiftUI
import FocusCore

// MARK: - ContentView

/// Root view that manages the authorization flow and main tab navigation.
/// Shows authorization/onboarding when status is `.notDetermined`,
/// denied explanation when `.denied`, and the main tab bar when `.approved`.
struct ContentView: View {
    @Bindable var viewModel: AuthorizationViewModel
    let dependencies: DependencyContainer
    var notificationService: FocusNotificationService = FocusNotificationService()

    var body: some View {
        switch viewModel.authorizationStatus {
        case .notDetermined:
            AuthorizationView(viewModel: viewModel)
        case .denied:
            AuthorizationDeniedView(viewModel: viewModel)
        case .approved:
            MainTabView(
                dependencies: dependencies,
                notificationService: notificationService
            )
        }
    }
}

// MARK: - MainTabView

/// The main tab bar with Focus, Deep Focus, Stats, and Settings tabs.
/// Focus tab is selected by default.
/// Includes focus notification banner overlay for in-app notifications.
struct MainTabView: View {
    let dependencies: DependencyContainer
    let notificationService: FocusNotificationService
    @State private var selectedTab: Tab = .focus
    @State private var sessionManager: DeepFocusSessionManager

    enum Tab: String, CaseIterable {
        case focus
        case deepFocus
        case stats
        case settings
    }

    init(dependencies: DependencyContainer, notificationService: FocusNotificationService) {
        self.dependencies = dependencies
        self.notificationService = notificationService
        self._sessionManager = State(initialValue: DeepFocusSessionManager(
            sharedStateService: dependencies.sharedStateService
        ))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FocusTabView(
                shieldService: dependencies.shieldService,
                monitoringService: dependencies.monitoringService
            )
                .tag(Tab.focus)
                .tabItem {
                    Label("Focus", systemImage: "moon.fill")
                }

            DeepFocusTabView(sessionManager: sessionManager)
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
        .focusNotificationOverlay(service: notificationService)
        .task {
            // Recover orphaned session on launch
            sessionManager.recoverOrphanedSession()
        }
    }
}
