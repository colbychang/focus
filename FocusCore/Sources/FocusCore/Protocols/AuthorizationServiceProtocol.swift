import Foundation

// MARK: - AuthorizationStatus

/// Represents the current authorization state for Screen Time access.
public enum AuthorizationStatus: String, Codable, CaseIterable, Sendable {
    /// Authorization has not been requested yet.
    case notDetermined
    /// The user has approved Screen Time access.
    case approved
    /// The user has denied Screen Time access.
    case denied
}

// MARK: - AuthorizationServiceProtocol

/// Protocol abstracting FamilyControls authorization.
/// Real implementation wraps `AuthorizationCenter.shared`;
/// mock implementation simulates approve/deny paths for testing.
public protocol AuthorizationServiceProtocol: AnyObject, Sendable {
    /// Request authorization for Screen Time access.
    /// Throws if the authorization request fails.
    func requestAuthorization() async throws

    /// The current authorization status.
    var authorizationStatus: AuthorizationStatus { get }
}
