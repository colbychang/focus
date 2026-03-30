import Foundation

// MARK: - DependencyContainer

/// A container for all protocol-based service dependencies.
/// Enables dependency injection throughout the app.
/// Uses mock implementations by default for testing without the Family Controls entitlement.
public final class DependencyContainer: @unchecked Sendable {

    /// The authorization service for Screen Time access.
    public let authorizationService: AuthorizationServiceProtocol

    /// The shield service for app blocking.
    public let shieldService: ShieldServiceProtocol

    /// The monitoring service for device activity schedules.
    public let monitoringService: MonitoringServiceProtocol

    /// The live activity service for break timers.
    public let liveActivityService: LiveActivityServiceProtocol

    /// The shared state service for cross-extension UserDefaults.
    public let sharedStateService: SharedStateService

    // MARK: - Initialization

    /// Creates a dependency container with the provided services.
    ///
    /// - Parameters:
    ///   - authorizationService: The authorization service to use.
    ///   - shieldService: The shield service to use.
    ///   - monitoringService: The monitoring service to use.
    ///   - liveActivityService: The live activity service to use.
    ///   - sharedStateService: The shared state service to use.
    public init(
        authorizationService: AuthorizationServiceProtocol,
        shieldService: ShieldServiceProtocol,
        monitoringService: MonitoringServiceProtocol,
        liveActivityService: LiveActivityServiceProtocol,
        sharedStateService: SharedStateService
    ) {
        self.authorizationService = authorizationService
        self.shieldService = shieldService
        self.monitoringService = monitoringService
        self.liveActivityService = liveActivityService
        self.sharedStateService = sharedStateService
    }

    // MARK: - Mock Factory

    /// Creates a dependency container with all mock services.
    /// Used for testing and when the Family Controls entitlement is unavailable.
    public static func mock(
        authorizationService: MockAuthorizationService = MockAuthorizationService(),
        shieldService: MockShieldService = MockShieldService(),
        monitoringService: MockMonitoringService = MockMonitoringService(),
        liveActivityService: MockLiveActivityService = MockLiveActivityService(),
        sharedStateService: SharedStateService = SharedStateService()
    ) -> DependencyContainer {
        DependencyContainer(
            authorizationService: authorizationService,
            shieldService: shieldService,
            monitoringService: monitoringService,
            liveActivityService: liveActivityService,
            sharedStateService: sharedStateService
        )
    }
}
