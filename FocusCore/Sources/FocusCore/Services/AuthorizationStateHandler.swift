import Foundation
import SwiftData

// MARK: - AuthorizationStateHandler

/// Handles authorization state changes for focus mode management.
///
/// When authorization is revoked (mock scenario):
/// - Clears ALL shields from ALL active profiles
/// - Stops ALL monitoring schedules
/// - Preserves ALL historical session data (SwiftData records untouched)
/// - Updates profile active states
///
/// When re-authorized:
/// - Existing profiles, schedules, and history remain intact
/// - Active profiles can be re-activated by the user
/// - No automatic re-activation (user must explicitly re-enable)
@MainActor
public final class AuthorizationStateHandler {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let shieldService: ShieldServiceProtocol
    private let monitoringService: MonitoringServiceProtocol

    // MARK: - Initialization

    /// Creates an authorization state handler.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData model context.
    ///   - shieldService: The shield service for clearing shields.
    ///   - monitoringService: The monitoring service for stopping monitors.
    public init(
        modelContext: ModelContext,
        shieldService: ShieldServiceProtocol,
        monitoringService: MonitoringServiceProtocol
    ) {
        self.modelContext = modelContext
        self.shieldService = shieldService
        self.monitoringService = monitoringService
    }

    // MARK: - Handle Revocation

    /// Handles authorization being revoked.
    /// Clears all shields and stops all monitoring, but preserves all data.
    ///
    /// - Returns: The number of profiles that were deactivated.
    @discardableResult
    public func handleAuthorizationRevoked() -> Int {
        var deactivatedCount = 0

        // Fetch all profiles
        let descriptor = FetchDescriptor<FocusMode>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let profiles = try? modelContext.fetch(descriptor) else { return 0 }

        for profile in profiles {
            // Clear shields for all profiles (active or not, to be safe)
            let storeName = profile.id.uuidString
            shieldService.clearShields(storeName: storeName)

            // Stop monitoring for all profiles
            monitoringService.stopMonitoring(activityNames: [storeName])

            // Update active state
            if profile.isActive {
                profile.isActive = false
                profile.isManuallyActivated = false
                deactivatedCount += 1
            }
        }

        try? modelContext.save()

        return deactivatedCount
    }

    // MARK: - Handle Re-authorization

    /// Handles re-authorization after previous revocation.
    /// Existing profiles and history remain intact.
    /// Does NOT automatically re-activate profiles — user must do so manually.
    ///
    /// - Returns: The total number of profiles available after re-auth.
    @discardableResult
    public func handleReauthorization() -> Int {
        let descriptor = FetchDescriptor<FocusMode>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let profiles = try? modelContext.fetch(descriptor) else { return 0 }
        return profiles.count
    }

    // MARK: - Verify Data Integrity

    /// Verifies that historical session data is preserved after auth changes.
    /// Used for testing to confirm that revocation does NOT delete session data.
    ///
    /// - Returns: The total number of ScreenTimeEntry and DeepFocusSession records.
    public func countHistoricalRecords() -> (screenTimeEntries: Int, deepFocusSessions: Int) {
        let entryDescriptor = FetchDescriptor<ScreenTimeEntry>()
        let sessionDescriptor = FetchDescriptor<DeepFocusSession>()

        let entries = (try? modelContext.fetch(entryDescriptor))?.count ?? 0
        let sessions = (try? modelContext.fetch(sessionDescriptor))?.count ?? 0

        return (entries, sessions)
    }
}
