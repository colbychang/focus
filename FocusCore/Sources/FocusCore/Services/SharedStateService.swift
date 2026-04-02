import Foundation

// MARK: - SharedStateKey

/// Keys for shared state stored in App Group UserDefaults.
/// Each key follows the flag + timestamp pattern.
public enum SharedStateKey: String, CaseIterable, Sendable {
    // Session state
    case isSessionActive = "isSessionActive"
    case sessionActiveTimestamp = "sessionActiveTimestamp"

    // Break state
    case isOnBreak = "isOnBreak"
    case onBreakTimestamp = "onBreakTimestamp"

    // Bypass state
    case isBypassActive = "isBypassActive"
    case bypassActiveTimestamp = "bypassActiveTimestamp"

    // Unlock request (from shield extension)
    case unlockRequested = "unlockRequested"
    case unlockRequestedTimestamp = "unlockRequestedTimestamp"

    // Focus mode active state
    case isFocusModeActive = "isFocusModeActive"
    case focusModeActiveTimestamp = "focusModeActiveTimestamp"

    // Deep focus session ID for cross-extension reference
    case activeSessionID = "activeSessionID"

    // Last check timestamp
    case lastDayCheck = "lastDayCheck"

    // Focus session recording (DeviceActivityMonitor → main app reconciliation)
    // Stored as JSON arrays of session records in UserDefaults
    case pendingSessionRecords = "pendingSessionRecords"
    // Per-profile active session start timestamps (keyed by profile UUID)
    case activeSessionStarts = "activeSessionStarts"

    // Deep focus session persistence (survives background/termination)
    case deepFocusSessionData = "deepFocusSessionData"
    case deepFocusBackgroundTimestamp = "deepFocusBackgroundTimestamp"

    // Break state persistence (survives termination)
    case breakEndTime = "breakEndTime"
    case breakEndTimeTimestamp = "breakEndTimeTimestamp"
    case breakSessionRemaining = "breakSessionRemaining"
}

// MARK: - SharedStateService

/// Service for managing cross-extension shared state via App Group UserDefaults.
/// All boolean state flags are paired with timestamps to prevent stale state
/// from app crashes or unexpected termination.
///
/// Pattern: For each boolean flag, a corresponding timestamp is stored.
/// When reading state, both the flag AND the timestamp are checked.
/// If the timestamp is in the past (for expiring state), the state is considered expired
/// regardless of the flag value.
public final class SharedStateService: @unchecked Sendable {

    // MARK: - Properties

    /// The UserDefaults instance backed by the App Group.
    private let defaults: UserDefaults

    /// The current date provider (injectable for testing).
    private let dateProvider: () -> Date

    // MARK: - Initialization

    /// Creates a shared state service.
    ///
    /// - Parameters:
    ///   - suiteName: The App Group suite name. Defaults to `FocusCore.appGroupIdentifier`.
    ///   - dateProvider: A closure providing the current date. Defaults to `Date()`.
    public init(
        suiteName: String? = nil,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        let suite = suiteName ?? FocusCore.appGroupIdentifier
        self.defaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        self.dateProvider = dateProvider
    }

    /// Creates a shared state service with an explicit UserDefaults instance.
    /// Primarily used for testing.
    ///
    /// - Parameters:
    ///   - defaults: The UserDefaults instance to use.
    ///   - dateProvider: A closure providing the current date. Defaults to `Date()`.
    public init(
        defaults: UserDefaults,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.dateProvider = dateProvider
    }

    // MARK: - Flag + Timestamp Operations

    /// Set a boolean flag with the current timestamp.
    ///
    /// - Parameters:
    ///   - value: The boolean value to set.
    ///   - flagKey: The key for the boolean flag.
    ///   - timestampKey: The key for the associated timestamp.
    public func setFlag(
        _ value: Bool,
        flagKey: SharedStateKey,
        timestampKey: SharedStateKey
    ) {
        defaults.set(value, forKey: flagKey.rawValue)
        defaults.set(dateProvider().timeIntervalSince1970, forKey: timestampKey.rawValue)
    }

    /// Read a boolean flag, validating against its timestamp.
    /// Returns `false` if the flag is not set.
    ///
    /// - Parameters:
    ///   - flagKey: The key for the boolean flag.
    ///   - timestampKey: The key for the associated timestamp.
    /// - Returns: The current flag value.
    public func getFlag(
        flagKey: SharedStateKey,
        timestampKey: SharedStateKey
    ) -> Bool {
        let flag = defaults.bool(forKey: flagKey.rawValue)
        let timestamp = defaults.double(forKey: timestampKey.rawValue)

        // If no timestamp exists, flag is not valid
        guard timestamp > 0 else { return false }

        return flag
    }

    /// Read a boolean flag with expiration check.
    /// Returns `false` if the flag is expired (timestamp is before the expiration date).
    ///
    /// - Parameters:
    ///   - flagKey: The key for the boolean flag.
    ///   - timestampKey: The key for the associated timestamp.
    ///   - maxAge: Maximum age in seconds for the flag to be considered valid.
    /// - Returns: The flag value, or `false` if expired.
    public func getFlagWithExpiry(
        flagKey: SharedStateKey,
        timestampKey: SharedStateKey,
        maxAge: TimeInterval
    ) -> Bool {
        let flag = defaults.bool(forKey: flagKey.rawValue)
        let timestamp = defaults.double(forKey: timestampKey.rawValue)

        guard flag, timestamp > 0 else { return false }

        let flagDate = Date(timeIntervalSince1970: timestamp)
        let elapsed = dateProvider().timeIntervalSince(flagDate)

        return elapsed < maxAge
    }

    /// Get the timestamp associated with a flag.
    ///
    /// - Parameter timestampKey: The key for the timestamp.
    /// - Returns: The stored date, or `nil` if no timestamp is stored.
    public func getTimestamp(for timestampKey: SharedStateKey) -> Date? {
        let timestamp = defaults.double(forKey: timestampKey.rawValue)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Convenience State Methods

    /// Set the session active state with current timestamp.
    public func setSessionActive(_ active: Bool) {
        setFlag(active, flagKey: .isSessionActive, timestampKey: .sessionActiveTimestamp)
    }

    /// Check if a session is currently active.
    public func isSessionActive() -> Bool {
        getFlag(flagKey: .isSessionActive, timestampKey: .sessionActiveTimestamp)
    }

    /// Set the break state with current timestamp.
    public func setOnBreak(_ onBreak: Bool) {
        setFlag(onBreak, flagKey: .isOnBreak, timestampKey: .onBreakTimestamp)
    }

    /// Check if currently on break.
    public func isOnBreak() -> Bool {
        getFlag(flagKey: .isOnBreak, timestampKey: .onBreakTimestamp)
    }

    /// Set the bypass active state with current timestamp.
    public func setBypassActive(_ active: Bool) {
        setFlag(active, flagKey: .isBypassActive, timestampKey: .bypassActiveTimestamp)
    }

    /// Check if bypass is currently active.
    public func isBypassActive() -> Bool {
        getFlag(flagKey: .isBypassActive, timestampKey: .bypassActiveTimestamp)
    }

    /// Set the focus mode active state with current timestamp.
    public func setFocusModeActive(_ active: Bool) {
        setFlag(active, flagKey: .isFocusModeActive, timestampKey: .focusModeActiveTimestamp)
    }

    /// Check if focus mode is currently active.
    public func isFocusModeActive() -> Bool {
        getFlag(flagKey: .isFocusModeActive, timestampKey: .focusModeActiveTimestamp)
    }

    /// Set the unlock request flag with current timestamp.
    public func setUnlockRequested(_ requested: Bool) {
        setFlag(requested, flagKey: .unlockRequested, timestampKey: .unlockRequestedTimestamp)
    }

    /// Check if an unlock has been requested.
    public func isUnlockRequested() -> Bool {
        getFlag(flagKey: .unlockRequested, timestampKey: .unlockRequestedTimestamp)
    }

    // MARK: - String/Data Operations

    /// Set a string value for a key.
    public func setString(_ value: String?, forKey key: SharedStateKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    /// Get a string value for a key.
    public func getString(forKey key: SharedStateKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    /// Set data for a key.
    public func setData(_ value: Data?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    /// Get data for a key.
    public func getData(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    // MARK: - Cleanup

    /// Remove a specific key from UserDefaults.
    public func removeValue(forKey key: SharedStateKey) {
        defaults.removeObject(forKey: key.rawValue)
    }

    /// Remove all shared state values.
    public func removeAll() {
        for key in SharedStateKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}
