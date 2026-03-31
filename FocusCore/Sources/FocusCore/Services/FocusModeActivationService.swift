import Foundation
import SwiftData

// MARK: - FocusModeActivationError

/// Errors that can occur during focus mode activation/deactivation.
public enum FocusModeActivationError: Error, LocalizedError, Equatable {
    /// The profile was not found.
    case profileNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "Profile with ID \(id) not found"
        }
    }
}

// MARK: - FocusModeActivationService

/// Service responsible for activating and deactivating focus mode profiles.
/// Manages shield application via `ShieldServiceProtocol` using named stores
/// (one per profile UUID) and persists activation state in SwiftData.
///
/// Key behaviors:
/// - Activation sets shields on ALL three dimensions (apps, categories, web domains).
/// - Deactivation clears the named store.
/// - No-op for already-active or already-inactive profiles.
/// - Multiple profiles can be active simultaneously with independent stores.
/// - Manual activation sets `isManuallyActivated` flag so `intervalDidEnd` does not deactivate.
/// - Editing blocked apps on an active profile immediately updates the store.
@MainActor
public final class FocusModeActivationService {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let shieldService: ShieldServiceProtocol

    // MARK: - Initialization

    /// Creates an activation service with the given dependencies.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData model context for persistence.
    ///   - shieldService: The shield service for applying/clearing shields.
    public init(
        modelContext: ModelContext,
        shieldService: ShieldServiceProtocol
    ) {
        self.modelContext = modelContext
        self.shieldService = shieldService
    }

    // MARK: - Activate

    /// Activates a focus mode profile by applying shields to its named store.
    /// Sets ALL three shield dimensions: applications, applicationCategories, and webDomainCategories.
    ///
    /// No-op if the profile is already active.
    ///
    /// - Parameter profile: The focus mode profile to activate.
    public func activate(profile: FocusMode) {
        // No-op if already active
        guard !profile.isActive else { return }

        let storeName = storeName(for: profile)

        // Deserialize tokens from the profile
        let appTokens = deserializeTokens(from: profile.serializedAppTokens)
        let categoryTokens = deserializeTokens(from: profile.serializedCategoryTokens)
        let webDomainTokens = deserializeTokens(from: profile.serializedWebDomainTokens)

        // Apply shields on all three dimensions
        shieldService.applyShields(
            storeName: storeName,
            applications: appTokens,
            categories: categoryTokens,
            webDomains: webDomainTokens
        )

        // Update model state
        profile.isActive = true
        profile.isManuallyActivated = true
        try? modelContext.save()
    }

    // MARK: - Deactivate

    /// Deactivates a focus mode profile by clearing its named store.
    ///
    /// No-op if the profile is already inactive.
    ///
    /// - Parameter profile: The focus mode profile to deactivate.
    public func deactivate(profile: FocusMode) {
        // No-op if already inactive
        guard profile.isActive else { return }

        let storeName = storeName(for: profile)

        // Clear shields from the named store
        shieldService.clearShields(storeName: storeName)

        // Update model state
        profile.isActive = false
        profile.isManuallyActivated = false
        try? modelContext.save()
    }

    // MARK: - Update Active Profile Shields

    /// Updates the shields for an active profile when its blocked apps are edited.
    /// If the profile is not active, this is a no-op.
    ///
    /// - Parameter profile: The focus mode profile whose shields should be refreshed.
    public func refreshShieldsIfActive(profile: FocusMode) {
        guard profile.isActive else { return }

        let storeName = storeName(for: profile)

        // Deserialize updated tokens
        let appTokens = deserializeTokens(from: profile.serializedAppTokens)
        let categoryTokens = deserializeTokens(from: profile.serializedCategoryTokens)
        let webDomainTokens = deserializeTokens(from: profile.serializedWebDomainTokens)

        // Re-apply shields with updated tokens
        shieldService.applyShields(
            storeName: storeName,
            applications: appTokens,
            categories: categoryTokens,
            webDomains: webDomainTokens
        )
    }

    // MARK: - Query

    /// Checks whether a profile is currently active.
    ///
    /// - Parameter profile: The profile to check.
    /// - Returns: `true` if the profile is active.
    public func isActive(profile: FocusMode) -> Bool {
        profile.isActive
    }

    // MARK: - Helpers

    /// Generates the store name for a focus mode profile.
    /// Uses the profile's UUID for deterministic naming across launches.
    ///
    /// - Parameter profile: The focus mode profile.
    /// - Returns: The store name string.
    public func storeName(for profile: FocusMode) -> String {
        profile.id.uuidString
    }

    /// Deserializes token data from a serialized blob.
    ///
    /// - Parameter data: The serialized token data, or `nil`.
    /// - Returns: A set of token Data values, or `nil` if no data.
    private func deserializeTokens(from data: Data?) -> Set<Data>? {
        guard let data = data else { return nil }
        return try? TokenSerializer.deserialize(data: data)
    }
}
