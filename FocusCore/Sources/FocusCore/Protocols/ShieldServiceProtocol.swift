import Foundation

// MARK: - ShieldServiceProtocol

/// Protocol abstracting ManagedSettingsStore shield operations.
/// Uses `Data` for serialized tokens since `ApplicationToken`, `ActivityCategoryToken`,
/// and `WebDomainToken` are unavailable without the Family Controls entitlement.
public protocol ShieldServiceProtocol: AnyObject, Sendable {
    /// Apply shields to a named store.
    ///
    /// - Parameters:
    ///   - storeName: The name of the ManagedSettingsStore to apply shields to.
    ///   - applications: Serialized application tokens to shield, or nil.
    ///   - categories: Serialized category tokens to shield, or nil.
    ///   - webDomains: Serialized web domain tokens to shield, or nil.
    func applyShields(
        storeName: String,
        applications: Set<Data>?,
        categories: Set<Data>?,
        webDomains: Set<Data>?
    )

    /// Clear all shields from a named store.
    ///
    /// - Parameter storeName: The name of the ManagedSettingsStore to clear.
    func clearShields(storeName: String)

    /// Check whether a named store currently has active shields.
    ///
    /// - Parameter storeName: The name of the ManagedSettingsStore to check.
    /// - Returns: `true` if the store has active shields, `false` otherwise.
    func isShielding(storeName: String) -> Bool
}
