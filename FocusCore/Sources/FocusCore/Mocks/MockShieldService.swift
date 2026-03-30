import Foundation

// MARK: - MockShieldService

/// Mock implementation of `ShieldServiceProtocol` for testing.
/// Tracks per-store shield state and records all method calls.
public final class MockShieldService: ShieldServiceProtocol, @unchecked Sendable {

    // MARK: - Shield State

    /// Represents the shield configuration for a single store.
    public struct ShieldState: Equatable {
        public let applications: Set<Data>?
        public let categories: Set<Data>?
        public let webDomains: Set<Data>?

        public init(
            applications: Set<Data>?,
            categories: Set<Data>?,
            webDomains: Set<Data>?
        ) {
            self.applications = applications
            self.categories = categories
            self.webDomains = webDomains
        }
    }

    /// Current shield state per store name.
    public private(set) var storeStates: [String: ShieldState] = [:]

    // MARK: - Call Recording

    /// Records of `applyShields` calls.
    public struct ApplyShieldsCall: Equatable {
        public let storeName: String
        public let applications: Set<Data>?
        public let categories: Set<Data>?
        public let webDomains: Set<Data>?
    }

    /// All recorded `applyShields` calls.
    public private(set) var applyShieldsCalls: [ApplyShieldsCall] = []

    /// All recorded `clearShields` calls (store names).
    public private(set) var clearShieldsCalls: [String] = []

    /// All recorded `isShielding` calls (store names).
    public private(set) var isShieldingCalls: [String] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Protocol Implementation

    public func applyShields(
        storeName: String,
        applications: Set<Data>?,
        categories: Set<Data>?,
        webDomains: Set<Data>?
    ) {
        let call = ApplyShieldsCall(
            storeName: storeName,
            applications: applications,
            categories: categories,
            webDomains: webDomains
        )
        applyShieldsCalls.append(call)

        storeStates[storeName] = ShieldState(
            applications: applications,
            categories: categories,
            webDomains: webDomains
        )
    }

    public func clearShields(storeName: String) {
        clearShieldsCalls.append(storeName)
        storeStates.removeValue(forKey: storeName)
    }

    public func isShielding(storeName: String) -> Bool {
        isShieldingCalls.append(storeName)
        return storeStates[storeName] != nil
    }

    // MARK: - Test Helpers

    /// Reset all call records and state.
    public func reset() {
        storeStates.removeAll()
        applyShieldsCalls.removeAll()
        clearShieldsCalls.removeAll()
        isShieldingCalls.removeAll()
    }
}
