import Foundation
import FocusCore

// MARK: - AuthorizationViewModel

/// ViewModel for managing Screen Time authorization state and flow.
/// Uses @Observable (Observation framework) per project conventions.
@MainActor
@Observable
final class AuthorizationViewModel {

    // MARK: - State

    /// The current authorization status.
    private(set) var authorizationStatus: AuthorizationStatus

    /// Whether an authorization request is in progress.
    private(set) var isRequesting: Bool = false

    /// Error message to display if authorization fails.
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    /// The authorization service (protocol-based for testability).
    let authorizationService: AuthorizationServiceProtocol

    // MARK: - Initialization

    /// Creates an AuthorizationViewModel with the given authorization service.
    ///
    /// - Parameter authorizationService: The authorization service to use.
    init(authorizationService: AuthorizationServiceProtocol) {
        self.authorizationService = authorizationService
        self.authorizationStatus = authorizationService.authorizationStatus
    }

    // MARK: - Actions

    /// Request Screen Time authorization from the user.
    func requestAuthorization() async {
        isRequesting = true
        errorMessage = nil

        do {
            try await authorizationService.requestAuthorization()
            authorizationStatus = authorizationService.authorizationStatus
        } catch {
            authorizationStatus = authorizationService.authorizationStatus
            errorMessage = error.localizedDescription
        }

        isRequesting = false
    }

    /// Refresh the current authorization status from the service.
    func refreshStatus() {
        authorizationStatus = authorizationService.authorizationStatus
    }
}
