import Foundation

// MARK: - DeepFocusDuration

/// Constants and validation for deep focus session durations.
public enum DeepFocusDuration: Sendable {
    /// Minimum allowed duration in minutes.
    public static let minimumMinutes: Int = 5
    /// Maximum allowed duration in minutes.
    public static let maximumMinutes: Int = 480
    /// Preset duration options in minutes.
    public static let presets: [Int] = [30, 60, 90, 120]

    /// Validates whether a duration in minutes is within the allowed range.
    ///
    /// - Parameter minutes: The duration to validate.
    /// - Returns: `true` if the duration is valid (between min and max inclusive).
    public static func isValid(minutes: Int) -> Bool {
        minutes >= minimumMinutes && minutes <= maximumMinutes
    }
}

// MARK: - DeepFocusTimerFormatter

/// Formats remaining seconds into a display string.
/// Uses MM:SS for durations under 60 minutes and H:MM:SS for 60+ minutes.
public enum DeepFocusTimerFormatter: Sendable {
    /// Formats the given seconds into a timer display string.
    ///
    /// - Parameter seconds: The remaining seconds (will be clamped to 0 if negative).
    /// - Returns: A formatted string like "29:59" or "1:00:00".
    public static func format(seconds: Int) -> String {
        let clamped = max(seconds, 0)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - PersistedSessionState

/// Serializable representation of a deep focus session state for UserDefaults persistence.
/// Used to survive app backgrounding and termination.
public struct PersistedSessionState: Codable, Sendable {
    public let sessionID: UUID
    public let startTime: Date
    public let configuredDurationSeconds: Int
    public let remainingSeconds: Int
    public let status: String // SessionStatus raw value
    public let bypassCount: Int
    public let breakCount: Int
    public let totalBreakDuration: TimeInterval
    public let savedAt: Date

    public init(
        sessionID: UUID,
        startTime: Date,
        configuredDurationSeconds: Int,
        remainingSeconds: Int,
        status: String,
        bypassCount: Int,
        breakCount: Int,
        totalBreakDuration: TimeInterval,
        savedAt: Date
    ) {
        self.sessionID = sessionID
        self.startTime = startTime
        self.configuredDurationSeconds = configuredDurationSeconds
        self.remainingSeconds = remainingSeconds
        self.status = status
        self.bypassCount = bypassCount
        self.breakCount = breakCount
        self.totalBreakDuration = totalBreakDuration
        self.savedAt = savedAt
    }
}

// MARK: - DeepFocusSessionManagerError

/// Errors that can occur during deep focus session operations.
public enum DeepFocusSessionManagerError: Error, LocalizedError, Equatable {
    /// Cannot start a new session while one is already active.
    case sessionAlreadyActive
    /// The specified duration is invalid.
    case invalidDuration(Int)

    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Cannot start a new session while one is active"
        case .invalidDuration(let minutes):
            return "Duration \(minutes) minutes is outside the allowed range (\(DeepFocusDuration.minimumMinutes)-\(DeepFocusDuration.maximumMinutes) minutes)"
        }
    }
}

// MARK: - DeepFocusSessionManager

/// Manages the lifecycle of a deep focus session including timer, state machine,
/// background/foreground reconciliation, and persistence.
///
/// State machine:
/// ```
/// .idle → .active → .completed
///            ↓           ↑
///        .onBreak ───────┘
///            ↓           ↑
///      .bypassing ───────┘
///            ↓
///       .abandoned
/// ```
@MainActor
@Observable
public final class DeepFocusSessionManager {

    // MARK: - Published State

    /// The current session status.
    public private(set) var sessionStatus: SessionStatus = .idle

    /// Remaining seconds in the current session.
    public private(set) var remainingSeconds: Int = 0

    /// Formatted remaining time string.
    public var formattedTimeRemaining: String {
        DeepFocusTimerFormatter.format(seconds: remainingSeconds)
    }

    /// The configured duration in seconds for the current/last session.
    public private(set) var configuredDurationSeconds: Int = 0

    /// Unique ID of the current session.
    public private(set) var currentSessionID: UUID?

    /// Start time of the current session.
    public private(set) var sessionStartTime: Date?

    /// Number of bypasses in the current session.
    public var bypassCount: Int = 0

    /// Number of breaks in the current session.
    public var breakCount: Int = 0

    /// Total break duration in seconds for the current session.
    public var totalBreakDuration: TimeInterval = 0

    /// Whether the session is in an active-like state (active, onBreak, or bypassing).
    public var isSessionRunning: Bool {
        switch sessionStatus {
        case .active, .onBreak, .bypassing:
            return true
        case .idle, .completed, .abandoned:
            return false
        }
    }

    // MARK: - Private State

    /// Timer for 1-second ticks.
    private var timer: Timer?

    /// Timestamp when the app entered the background (for wall-clock reconciliation).
    private var backgroundEntryTimestamp: Date?

    /// Flag to ensure completion triggers exactly once.
    private var completionTriggered: Bool = false

    /// Callback invoked when the session completes (timer reaches 0).
    public var onSessionCompleted: (() -> Void)?

    /// Callback invoked when the session is abandoned.
    public var onSessionAbandoned: (() -> Void)?

    // MARK: - Dependencies

    private let sharedStateService: SharedStateService
    private let dateProvider: () -> Date

    // MARK: - Initialization

    /// Creates a DeepFocusSessionManager with the given dependencies.
    ///
    /// - Parameters:
    ///   - sharedStateService: Service for persisting state to UserDefaults.
    ///   - dateProvider: Closure returning the current date (injectable for testing).
    public init(
        sharedStateService: SharedStateService,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sharedStateService = sharedStateService
        self.dateProvider = dateProvider
    }

    // MARK: - Session Lifecycle

    /// Starts a new deep focus session.
    ///
    /// - Parameters:
    ///   - durationMinutes: The session duration in minutes (5-480).
    ///   - allowedApps: Optional serialized token data for allowed apps.
    /// - Throws: `DeepFocusSessionManagerError.sessionAlreadyActive` if a session is running,
    ///           `DeepFocusSessionManagerError.invalidDuration` if duration is out of range.
    public func startSession(durationMinutes: Int, allowedApps: Data? = nil) throws {
        // Cannot start while active
        guard !isSessionRunning else {
            throw DeepFocusSessionManagerError.sessionAlreadyActive
        }

        // Validate duration
        guard DeepFocusDuration.isValid(minutes: durationMinutes) else {
            throw DeepFocusSessionManagerError.invalidDuration(durationMinutes)
        }

        let durationSeconds = durationMinutes * 60
        let sessionID = UUID()
        let startTime = dateProvider()

        // Reset state
        currentSessionID = sessionID
        sessionStartTime = startTime
        configuredDurationSeconds = durationSeconds
        remainingSeconds = durationSeconds
        sessionStatus = .active
        bypassCount = 0
        breakCount = 0
        totalBreakDuration = 0
        completionTriggered = false
        backgroundEntryTimestamp = nil

        // Mark session active in shared state
        sharedStateService.setSessionActive(true)
        sharedStateService.setString(sessionID.uuidString, forKey: .activeSessionID)

        // Persist state
        persistState()

        // Start the timer
        startTimer()
    }

    /// Starts a test session with an exact duration in seconds, bypassing validation.
    /// Used only for UI testing via `--deep-focus-test-seconds` launch argument.
    ///
    /// - Parameter durationSeconds: The session duration in seconds.
    public func startTestSession(durationSeconds: Int) {
        guard !isSessionRunning else { return }

        let sessionID = UUID()
        let startTime = dateProvider()

        currentSessionID = sessionID
        sessionStartTime = startTime
        configuredDurationSeconds = durationSeconds
        remainingSeconds = durationSeconds
        sessionStatus = .active
        bypassCount = 0
        breakCount = 0
        totalBreakDuration = 0
        completionTriggered = false
        backgroundEntryTimestamp = nil

        sharedStateService.setSessionActive(true)
        sharedStateService.setString(sessionID.uuidString, forKey: .activeSessionID)

        persistState()
        startTimer()
    }

    /// Abandons the current session.
    public func abandonSession() {
        guard isSessionRunning else { return }

        stopTimer()
        sessionStatus = .abandoned

        // Clear shared state
        sharedStateService.setSessionActive(false)
        clearPersistedState()

        onSessionAbandoned?()
    }

    // MARK: - Timer

    /// Starts the 1-second interval timer.
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timerTick()
            }
        }
    }

    /// Stops the timer.
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Called every second by the timer. Decrements remaining time and checks for completion.
    /// Timer ticks during both `.active` and `.bypassing` states (bypass does NOT pause the main timer).
    internal func timerTick() {
        guard sessionStatus == .active || sessionStatus == .bypassing else { return }

        remainingSeconds = max(remainingSeconds - 1, 0)

        if remainingSeconds <= 0 {
            completeSession()
        }
    }

    /// Completes the session (timer reached 0). Ensures single trigger.
    private func completeSession() {
        guard !completionTriggered else { return }
        completionTriggered = true

        stopTimer()
        remainingSeconds = 0
        sessionStatus = .completed

        // Clear shared state
        sharedStateService.setSessionActive(false)
        clearPersistedState()

        onSessionCompleted?()
    }

    // MARK: - Background/Foreground Reconciliation

    /// Called when the app enters the background. Saves state and records timestamp.
    public func handleBackgroundEntry() {
        guard isSessionRunning else { return }

        backgroundEntryTimestamp = dateProvider()
        stopTimer()
        persistState()

        // Store background timestamp separately for relaunch recovery
        if let timestamp = backgroundEntryTimestamp {
            let defaults = UserDefaults.standard
            defaults.set(timestamp.timeIntervalSince1970, forKey: SharedStateKey.deepFocusBackgroundTimestamp.rawValue)
        }
    }

    /// Called when the app returns to the foreground. Reconciles elapsed time using wall clock.
    public func handleForegroundEntry() {
        guard isSessionRunning else { return }

        if let backgroundTime = backgroundEntryTimestamp {
            let now = dateProvider()
            let elapsedWhileBackground = Int(now.timeIntervalSince(backgroundTime))

            if sessionStatus == .active || sessionStatus == .bypassing {
                // Subtract elapsed time from remaining, clamping at 0
                // Bypass does NOT pause the main timer, so we reconcile for both states
                remainingSeconds = max(remainingSeconds - elapsedWhileBackground, 0)

                if remainingSeconds <= 0 {
                    completeSession()
                    return
                }
            }
            // For .onBreak state, the main timer doesn't tick
            // (handled by the break flow manager)
        }

        backgroundEntryTimestamp = nil

        // Restart timer if still in active or bypassing state
        if sessionStatus == .active || sessionStatus == .bypassing {
            persistState()
            startTimer()
        }
    }

    // MARK: - Session Recovery (Relaunch)

    /// Attempts to recover an orphaned session from persisted state.
    /// Called on app launch to detect sessions interrupted by termination.
    ///
    /// - Returns: `true` if a session was recovered, `false` otherwise.
    @discardableResult
    public func recoverOrphanedSession() -> Bool {
        guard let persistedData = sharedStateService.getData(forKey: SharedStateKey.deepFocusSessionData.rawValue),
              let persisted = try? JSONDecoder().decode(PersistedSessionState.self, from: persistedData) else {
            return false
        }

        // Only recover sessions that were active, on break, or bypassing
        guard let status = SessionStatus(rawValue: persisted.status),
              status == .active || status == .onBreak || status == .bypassing else {
            clearPersistedState()
            return false
        }

        // Calculate elapsed time since the session was saved
        let now = dateProvider()
        let elapsedSinceSave = Int(now.timeIntervalSince(persisted.savedAt))
        let adjustedRemaining: Int

        if status == .active || status == .bypassing {
            // If active or bypassing, subtract elapsed time
            // (bypass does NOT pause the main timer)
            adjustedRemaining = max(persisted.remainingSeconds - elapsedSinceSave, 0)
        } else {
            // If on break, the main timer was paused
            adjustedRemaining = persisted.remainingSeconds
        }

        // If time has elapsed completely, auto-complete
        if adjustedRemaining <= 0 {
            // Restore minimal state for completion
            currentSessionID = persisted.sessionID
            sessionStartTime = persisted.startTime
            configuredDurationSeconds = persisted.configuredDurationSeconds
            remainingSeconds = 0
            bypassCount = persisted.bypassCount
            breakCount = persisted.breakCount
            totalBreakDuration = persisted.totalBreakDuration
            sessionStatus = .completed
            completionTriggered = true

            sharedStateService.setSessionActive(false)
            clearPersistedState()

            onSessionCompleted?()
            return true
        }

        // Resume the session
        currentSessionID = persisted.sessionID
        sessionStartTime = persisted.startTime
        configuredDurationSeconds = persisted.configuredDurationSeconds
        remainingSeconds = adjustedRemaining
        bypassCount = persisted.bypassCount
        breakCount = persisted.breakCount
        totalBreakDuration = persisted.totalBreakDuration
        sessionStatus = .active
        completionTriggered = false
        backgroundEntryTimestamp = nil

        sharedStateService.setSessionActive(true)
        persistState()
        startTimer()

        return true
    }

    // MARK: - State Persistence

    /// Persists the current session state to UserDefaults.
    private func persistState() {
        guard let sessionID = currentSessionID,
              let startTime = sessionStartTime else { return }

        let state = PersistedSessionState(
            sessionID: sessionID,
            startTime: startTime,
            configuredDurationSeconds: configuredDurationSeconds,
            remainingSeconds: remainingSeconds,
            status: sessionStatus.rawValue,
            bypassCount: bypassCount,
            breakCount: breakCount,
            totalBreakDuration: totalBreakDuration,
            savedAt: dateProvider()
        )

        if let data = try? JSONEncoder().encode(state) {
            sharedStateService.setData(data, forKey: SharedStateKey.deepFocusSessionData.rawValue)
        }
    }

    /// Clears persisted session state from UserDefaults.
    private func clearPersistedState() {
        sharedStateService.setData(nil, forKey: SharedStateKey.deepFocusSessionData.rawValue)
        UserDefaults.standard.removeObject(forKey: SharedStateKey.deepFocusBackgroundTimestamp.rawValue)
    }

    // MARK: - State Machine Transitions (for other managers)

    /// Transitions to the on-break state. Called by the break flow manager.
    public func transitionToBreak() {
        guard sessionStatus == .active else { return }
        sessionStatus = .onBreak
        stopTimer()
        persistState()
    }

    /// Resumes from break to active state. Called by the break flow manager.
    public func resumeFromBreak() {
        guard sessionStatus == .onBreak else { return }
        sessionStatus = .active
        persistState()
        startTimer()
    }

    /// Transitions to the bypassing state. Called by the bypass flow manager.
    public func transitionToBypassing() {
        guard sessionStatus == .active else { return }
        sessionStatus = .bypassing
        // Timer continues during bypass — don't stop it
        persistState()
    }

    /// Resumes from bypassing to active state. Called by the bypass flow manager.
    public func resumeFromBypassing() {
        guard sessionStatus == .bypassing else { return }
        sessionStatus = .active
        persistState()
    }

    // MARK: - Cleanup

    /// Resets the manager to idle state. Used for cleanup after session recording.
    public func resetToIdle() {
        stopTimer()
        sessionStatus = .idle
        remainingSeconds = 0
        configuredDurationSeconds = 0
        currentSessionID = nil
        sessionStartTime = nil
        bypassCount = 0
        breakCount = 0
        totalBreakDuration = 0
        completionTriggered = false
        backgroundEntryTimestamp = nil
        clearPersistedState()
    }

    // Note: Timer uses [weak self] in its callback closure, so it will
    // become a no-op when the manager is deallocated. No explicit deinit needed.
}
