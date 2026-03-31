import Foundation

// MARK: - ShieldActionResponse

/// The response type for shield action handling.
/// Mirrors `ManagedSettings.ShieldActionResponse` without importing the framework.
public enum ShieldActionResponseType: Equatable, Sendable {
    /// Close the shielded app.
    case close
    /// Defer the action (no response).
    case none
}

// MARK: - ShieldActionType

/// The type of shield action button pressed.
/// Mirrors `ManagedSettings.ShieldAction` without importing the framework.
public enum ShieldActionType: Equatable, Sendable {
    /// The primary button was pressed (e.g., "Request Access").
    case primaryButtonPressed
    /// The secondary button was pressed (e.g., "Close").
    case secondaryButtonPressed
}

// MARK: - ShieldActionHandler

/// Handles shield action button presses for the ShieldActionExtension.
/// Lives in FocusCore for shared access and testability.
///
/// - Primary button ("Request Access"): Writes an unlock request flag + timestamp
///   to App Group UserDefaults, then returns `.close`.
/// - Secondary button ("Close"): Returns `.close` immediately.
public final class ShieldActionHandler: @unchecked Sendable {

    // MARK: - Dependencies

    private let sharedStateService: SharedStateService

    // MARK: - Initialization

    /// Creates a handler with the given shared state service.
    ///
    /// - Parameter sharedStateService: The service for writing to App Group UserDefaults.
    public init(sharedStateService: SharedStateService) {
        self.sharedStateService = sharedStateService
    }

    /// Creates a handler using the default App Group UserDefaults.
    public convenience init() {
        self.init(sharedStateService: SharedStateService())
    }

    // MARK: - Action Handling

    /// Handles a shield action and returns the appropriate response.
    ///
    /// - Parameter action: The type of button that was pressed.
    /// - Returns: The action response (`.close` for both buttons).
    public func handle(action: ShieldActionType) -> ShieldActionResponseType {
        switch action {
        case .primaryButtonPressed:
            // Write unlock request flag + timestamp to App Group UserDefaults
            sharedStateService.setUnlockRequested(true)
            return .close

        case .secondaryButtonPressed:
            // Simply close without any side effect
            return .close
        }
    }
}
