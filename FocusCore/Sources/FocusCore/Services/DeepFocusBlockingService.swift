import Foundation

// MARK: - DeepFocusBlockingService

/// Manages app blocking for deep focus sessions.
/// On session start, applies shields with `.all(except: allowedTokens)` pattern
/// for applications, applicationCategories, AND webDomainCategories.
/// On session end (completed or abandoned), clears all shields.
///
/// Uses a dedicated named ManagedSettingsStore ("deep_focus") separate from
/// focus mode stores to ensure independence.
public final class DeepFocusBlockingService: @unchecked Sendable {

    // MARK: - Constants

    /// The store name used for deep focus blocking.
    /// Separate from per-profile focus mode stores.
    public static let storeName = "deep_focus"

    // MARK: - Dependencies

    private let shieldService: ShieldServiceProtocol

    // MARK: - State

    /// Whether blocking is currently active.
    public private(set) var isBlocking: Bool = false

    /// The current allowed apps configuration (for re-applying after break).
    public private(set) var currentAllowedTokens: Set<Data>?

    // MARK: - Initialization

    /// Creates a DeepFocusBlockingService.
    ///
    /// - Parameter shieldService: The shield service for applying/clearing shields.
    public init(shieldService: ShieldServiceProtocol) {
        self.shieldService = shieldService
    }

    // MARK: - Blocking Operations

    /// Applies blocking for a deep focus session.
    /// Uses `.all(except: allowedTokens)` pattern — blocks everything except the allowed apps.
    /// Sets shields on all three dimensions: applications, applicationCategories, and webDomainCategories.
    ///
    /// - Parameter allowedTokens: The set of serialized tokens for apps that should remain accessible.
    ///   Pass `nil` or empty set to block all apps.
    public func applyBlocking(allowedTokens: Set<Data>?) {
        currentAllowedTokens = allowedTokens

        // Apply shields with .all(except:) pattern
        // The allowed tokens serve as exceptions - everything else is blocked.
        // We set the same exceptions on all three dimensions to ensure comprehensive blocking
        // (prevents bypassing via Safari/web domains or app categories).
        shieldService.applyShields(
            storeName: Self.storeName,
            applications: allowedTokens,
            categories: allowedTokens,
            webDomains: allowedTokens
        )

        isBlocking = true
    }

    /// Clears all blocking for the deep focus session.
    /// Called when the session ends (completed or abandoned).
    /// This also clears the stored token config.
    public func clearBlocking() {
        shieldService.clearShields(storeName: Self.storeName)
        isBlocking = false
        currentAllowedTokens = nil
    }

    /// Temporarily removes blocking while preserving the token configuration.
    /// Used during breaks so that re-apply can restore the same blocking config.
    public func suspendBlocking() {
        shieldService.clearShields(storeName: Self.storeName)
        isBlocking = false
        // Intentionally does NOT clear currentAllowedTokens
    }

    /// Re-applies blocking with the same configuration.
    /// Used after a break ends to restore the previous blocking state.
    public func reapplyBlocking() {
        guard let tokens = currentAllowedTokens else {
            // If no previous config, apply full blocking
            applyBlocking(allowedTokens: nil)
            return
        }
        applyBlocking(allowedTokens: tokens)
    }
}
