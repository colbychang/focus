import Foundation

// MARK: - MockAuthorizationService

/// Mock implementation of `AuthorizationServiceProtocol` for testing.
/// Records all calls and allows configuration of simulated responses.
public final class MockAuthorizationService: AuthorizationServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// Whether `requestAuthorization()` should simulate approval (`true`) or denial (`false`).
    /// When `nil`, the call will throw `MockAuthorizationError.simulatedFailure`.
    public var shouldApprove: Bool?

    /// Custom error to throw when `shouldApprove` is `nil`.
    public var errorToThrow: Error?

    // MARK: - State

    /// The current simulated authorization status.
    public private(set) var authorizationStatus: AuthorizationStatus

    // MARK: - Call Recording

    /// Number of times `requestAuthorization()` has been called.
    public private(set) var requestAuthorizationCallCount: Int = 0

    /// Number of times `authorizationStatus` has been read.
    public private(set) var authorizationStatusReadCount: Int = 0

    // MARK: - Errors

    /// Errors that `MockAuthorizationService` can simulate.
    public enum MockAuthorizationError: Error, LocalizedError {
        case simulatedFailure

        public var errorDescription: String? {
            switch self {
            case .simulatedFailure:
                return "Simulated authorization failure"
            }
        }
    }

    // MARK: - Initialization

    /// Creates a new mock authorization service.
    ///
    /// - Parameters:
    ///   - initialStatus: The initial authorization status. Defaults to `.notDetermined`.
    ///   - shouldApprove: Whether future calls to `requestAuthorization()` should approve.
    public init(
        initialStatus: AuthorizationStatus = .notDetermined,
        shouldApprove: Bool? = true
    ) {
        self.authorizationStatus = initialStatus
        self.shouldApprove = shouldApprove
    }

    // MARK: - Protocol Implementation

    public func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1

        guard let shouldApprove = shouldApprove else {
            throw errorToThrow ?? MockAuthorizationError.simulatedFailure
        }

        if shouldApprove {
            authorizationStatus = .approved
        } else {
            authorizationStatus = .denied
        }
    }

    // MARK: - Test Helpers

    /// Reset all call counts and state to initial values.
    public func reset(to status: AuthorizationStatus = .notDetermined) {
        authorizationStatus = status
        requestAuthorizationCallCount = 0
        authorizationStatusReadCount = 0
    }
}
