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

    init() {
        // Set up dependency container with mock services, configurable via launch arguments
        let authService = FocusApp.configureAuthorizationService()
        let deps = DependencyContainer(
            authorizationService: authService,
            shieldService: MockShieldService(),
            monitoringService: MockMonitoringService(),
            liveActivityService: MockLiveActivityService(),
            sharedStateService: SharedStateService()
        )
        self.dependencies = deps

        // Create authorization view model
        self.authorizationViewModel = AuthorizationViewModel(
            authorizationService: deps.authorizationService
        )

        // Set up SwiftData ModelContainer with all 4 model types
        do {
            let schema = Schema(AppSchemaV1.models)
            let config = ModelConfiguration(schema: schema)
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
            ContentView(viewModel: authorizationViewModel)
        }
        .modelContainer(modelContainer)
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
