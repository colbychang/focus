import SwiftUI
import SwiftData
import FocusCore

@main
struct FocusApp: App {
    /// The dependency container for protocol-based services.
    /// Uses mock implementations while Family Controls entitlement is unavailable.
    let dependencies: DependencyContainer

    /// The authorization view model, created from the dependency container.
    let authorizationViewModel: AuthorizationViewModel

    /// SwiftData ModelContainer with all 4 model types.
    let modelContainer: ModelContainer

    /// The focus notification service for in-app banners.
    let notificationService: FocusNotificationService

    /// The focus session recorder for UserDefaults → SwiftData reconciliation.
    let sessionRecorder: FocusSessionRecorder

    /// Darwin notification observers for extension → app IPC.
    let focusModeStartedObserver: DarwinNotificationObserver
    let focusModeEndedObserver: DarwinNotificationObserver

    init() {
        // Set up dependency container with mock services, configurable via launch arguments
        let authService = FocusApp.configureAuthorizationService()
        let sharedState = SharedStateService()

        // Clear shared state for UI tests to prevent stale deep focus session recovery
        let useInMemory = ProcessInfo.processInfo.arguments.contains("--use-in-memory-store")
        if useInMemory {
            sharedState.removeAll()
        }

        let deps = DependencyContainer(
            authorizationService: authService,
            shieldService: MockShieldService(),
            monitoringService: MockMonitoringService(),
            liveActivityService: MockLiveActivityService(),
            sharedStateService: sharedState
        )
        self.dependencies = deps

        // Create authorization view model
        self.authorizationViewModel = AuthorizationViewModel(
            authorizationService: deps.authorizationService
        )

        // Create notification service
        // Use longer auto-dismiss in test mode so UI tests can observe the banner
        let isTestMode = ProcessInfo.processInfo.arguments.contains("--show-focus-notification")
        self.notificationService = FocusNotificationService(
            autoDismissDuration: isTestMode ? 30.0 : 3.0
        )

        // Create session recorder
        self.sessionRecorder = FocusSessionRecorder()

        // Set up Darwin notification observers for extension IPC
        // These forward focus mode lifecycle events to the notification service for in-app banners.
        // Darwin notifications carry no payload; the profile name is read from App Group UserDefaults.
        let notifService = self.notificationService
        let appGroupDefaults = UserDefaults(suiteName: FocusCore.appGroupIdentifier)

        self.focusModeStartedObserver = DarwinNotificationObserver(
            name: DarwinNotificationName.focusModeStarted
        ) {
            Task { @MainActor in
                // Read the most recent active session start to get the profile name
                let profileName = FocusApp.lastActiveProfileName(from: appGroupDefaults) ?? "Focus Mode"
                notifService.showActivation(profileName: profileName)
            }
        }
        self.focusModeEndedObserver = DarwinNotificationObserver(
            name: DarwinNotificationName.focusModeEnded
        ) {
            Task { @MainActor in
                let profileName = FocusApp.lastActiveProfileName(from: appGroupDefaults) ?? "Focus Mode"
                notifService.showDeactivation(profileName: profileName)
            }
        }
        focusModeStartedObserver.startObserving()
        focusModeEndedObserver.startObserving()

        // Set up SwiftData ModelContainer with all 4 model types
        // Use in-memory store when launched with --use-in-memory-store (for UI tests)
        do {
            let schema = Schema(AppSchemaV2.models)
            let useInMemory = ProcessInfo.processInfo.arguments.contains("--use-in-memory-store")
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: useInMemory
            )
            self.modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: authorizationViewModel,
                dependencies: dependencies,
                notificationService: notificationService
            )
            .task {
                // Reconcile extension-recorded sessions into SwiftData on launch
                sessionRecorder.reconcileSessions(modelContext: modelContainer.mainContext)
            }
            .task {
                // Check for launch argument to show a test notification
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--show-focus-notification") {
                    // Small delay to ensure the view is fully set up and observing
                    try? await Task.sleep(for: .milliseconds(500))

                    let isActivation = !args.contains("--notification-type-ended")
                    let profileName: String
                    if let idx = args.firstIndex(of: "--notification-profile-name"),
                       idx + 1 < args.count {
                        profileName = args[idx + 1]
                    } else {
                        profileName = "Work"
                    }

                    if isActivation {
                        notificationService.showActivation(profileName: profileName)
                    } else {
                        notificationService.showDeactivation(profileName: profileName)
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Darwin Notification Helpers

    /// Reads the most recently active profile name from App Group UserDefaults.
    /// Used by Darwin notification handlers to determine which profile to show in the banner.
    private static func lastActiveProfileName(from defaults: UserDefaults?) -> String? {
        guard let defaults else { return nil }
        guard let data = defaults.data(forKey: SharedStateKey.activeSessionStarts.rawValue),
              let activeStarts = try? JSONDecoder().decode([String: SessionRecord].self, from: data),
              let latestEntry = activeStarts.values.max(by: { $0.startTimestamp < $1.startTimestamp }) else {
            return nil
        }
        return latestEntry.profileName
    }

    // MARK: - Launch Argument Configuration

    /// Configures the authorization service based on launch arguments.
    /// Used by UI tests to control authorization behavior.
    ///
    /// Launch arguments:
    /// - `--auth-status notDetermined|approved|denied` — initial status
    /// - `--auth-approve` — requestAuthorization() will approve
    /// - `--auth-deny` — requestAuthorization() will deny
    /// - `--auth-retry-approve` — after first deny, second call approves
    private static func configureAuthorizationService() -> AuthorizationServiceProtocol {
        let args = ProcessInfo.processInfo.arguments

        // Determine initial status
        var initialStatus: AuthorizationStatus = .notDetermined
        if let statusIndex = args.firstIndex(of: "--auth-status"),
           statusIndex + 1 < args.count {
            switch args[statusIndex + 1] {
            case "approved":
                initialStatus = .approved
            case "denied":
                initialStatus = .denied
            default:
                initialStatus = .notDetermined
            }
        }

        // Determine approval behavior
        var shouldApprove: Bool? = true // default: approve
        if args.contains("--auth-deny") {
            shouldApprove = false
        }
        if args.contains("--auth-approve") {
            shouldApprove = true
        }

        // Handle retry-approve: deny first, then approve on second call
        if args.contains("--auth-retry-approve") && args.contains("--auth-deny") {
            return RetryApproveAuthorizationService(initialStatus: initialStatus)
        }

        return MockAuthorizationService(
            initialStatus: initialStatus,
            shouldApprove: shouldApprove
        )
    }
}

// MARK: - RetryApproveAuthorizationService

/// A mock authorization service that denies on first request and approves on retry.
/// Used for testing the deny → retry → approve flow in UI tests.
final class RetryApproveAuthorizationService: AuthorizationServiceProtocol, @unchecked Sendable {
    private(set) var authorizationStatus: AuthorizationStatus
    private var callCount = 0

    init(initialStatus: AuthorizationStatus) {
        self.authorizationStatus = initialStatus
    }

    func requestAuthorization() async throws {
        callCount += 1
        if callCount >= 2 {
            authorizationStatus = .approved
        } else {
            authorizationStatus = .denied
        }
    }
}
