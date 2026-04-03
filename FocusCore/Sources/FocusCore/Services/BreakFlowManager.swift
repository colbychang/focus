import Foundation

// MARK: - BreakFlowError

/// Errors that can occur during break flow operations.
public enum BreakFlowError: Error, LocalizedError, Equatable {
    /// Break duration must be between 1 and 5 minutes.
    case invalidDuration(Int)
    /// No active deep focus session.
    case noActiveSession
    /// A break is already in progress.
    case breakAlreadyActive
    /// Session is not in the correct state for a break.
    case invalidSessionState(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDuration(let minutes):
            return "Break duration must be 1-5 minutes, got \(minutes)"
        case .noActiveSession:
            return "No active deep focus session"
        case .breakAlreadyActive:
            return "A break is already in progress"
        case .invalidSessionState(let state):
            return "Cannot start break in session state: \(state)"
        }
    }
}

// MARK: - BreakState

/// The current state of the break flow.
public enum BreakState: Equatable, Sendable {
    /// No break active.
    case idle
    /// Break is active with the given end date and remaining seconds.
    case active(breakEndDate: Date, remainingSeconds: Int)
    /// Break has expired and needs cleanup.
    case expired
}

// MARK: - PersistedBreakState

/// Serializable break state for UserDefaults persistence (survives termination).
public struct PersistedBreakState: Codable, Sendable {
    public let breakEndTime: Date
    public let sessionRemainingSeconds: Int
    public let breakDurationMinutes: Int
    public let sessionID: UUID
    /// The allowed app tokens at the time the break started.
    /// Used to restore the correct blocking configuration on recovery after termination.
    public let allowedTokens: Set<Data>?

    public init(
        breakEndTime: Date,
        sessionRemainingSeconds: Int,
        breakDurationMinutes: Int,
        sessionID: UUID,
        allowedTokens: Set<Data>? = nil
    ) {
        self.breakEndTime = breakEndTime
        self.sessionRemainingSeconds = sessionRemainingSeconds
        self.breakDurationMinutes = breakDurationMinutes
        self.sessionID = sessionID
        self.allowedTokens = allowedTokens
    }
}

// MARK: - BreakFlowManager

/// Manages the break flow during deep focus sessions.
///
/// Flow:
/// 1. User selects break duration (1-5 minutes) and confirms.
/// 2. Deep focus timer is paused (remaining seconds frozen).
/// 3. App blocking is removed.
/// 4. Break countdown starts. A Live Activity is created (if enabled).
/// 5. After break expires: re-apply blocking with same config, resume deep focus timer.
/// 6. Break time does NOT count against session duration.
/// 7. If app is terminated during break, state is persisted to UserDefaults.
/// 8. On relaunch: if break expired → re-apply blocking, resume session.
///    If break still active → resume break countdown.
///
/// Edge cases:
/// - Break when 1 second remains: session resumes with 1s after break, then completes.
/// - Session does NOT auto-complete during break.
@MainActor
@Observable
public final class BreakFlowManager {

    // MARK: - Constants

    /// Valid break duration range in minutes.
    public static let minimumMinutes: Int = 1
    public static let maximumMinutes: Int = 5

    // MARK: - Published State

    /// The current break state.
    public private(set) var breakState: BreakState = .idle

    /// Whether a break is currently active.
    public var isBreakActive: Bool {
        if case .active = breakState { return true }
        return false
    }

    /// The break end date (when the break expires).
    public var breakEndDate: Date? {
        if case .active(let endDate, _) = breakState { return endDate }
        return nil
    }

    /// Remaining seconds in the current break.
    public var breakRemainingSeconds: Int {
        if case .active(_, let remaining) = breakState { return remaining }
        return 0
    }

    /// The current break duration in minutes (for display).
    public private(set) var currentBreakDurationMinutes: Int = 0

    // MARK: - Private State

    /// Timer for 1-second break countdown ticks. Invalidated in deinit to allow run loop exit in tests.
    nonisolated(unsafe) private var breakTimer: Timer?

    /// The break end date for wall-clock reconciliation.
    private var breakEndTime: Date?

    /// Flag to prevent duplicate break-end handling.
    private var breakEndTriggered: Bool = false

    /// The session remaining seconds when the break started (frozen value).
    private var frozenSessionRemaining: Int = 0

    /// Live Activity ID for the current break (if created).
    private var liveActivityID: String?

    // MARK: - Callbacks

    /// Called when the break expires and the session should resume.
    public var onBreakExpired: (() -> Void)?

    /// Called when a break starts.
    public var onBreakStarted: (() -> Void)?

    // MARK: - Dependencies

    private let sessionManager: DeepFocusSessionManager
    private let blockingService: DeepFocusBlockingService
    private let liveActivityService: LiveActivityServiceProtocol
    private let sharedStateService: SharedStateService
    private let dateProvider: () -> Date

    // MARK: - Initialization

    deinit {
        // Invalidate the timer to allow the run loop to exit cleanly (important in tests).
        breakTimer?.invalidate()
        breakTimer = nil
    }

    /// Creates a BreakFlowManager with the given dependencies.
    ///
    /// - Parameters:
    ///   - sessionManager: The session manager for state machine transitions.
    ///   - blockingService: The blocking service for removing/re-applying shields.
    ///   - liveActivityService: The live activity service for Dynamic Island timer.
    ///   - sharedStateService: The shared state service for cross-extension persistence.
    ///   - dateProvider: Closure returning the current date (injectable for testing).
    public init(
        sessionManager: DeepFocusSessionManager,
        blockingService: DeepFocusBlockingService,
        liveActivityService: LiveActivityServiceProtocol,
        sharedStateService: SharedStateService,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionManager = sessionManager
        self.blockingService = blockingService
        self.liveActivityService = liveActivityService
        self.sharedStateService = sharedStateService
        self.dateProvider = dateProvider
    }

    // MARK: - Break Lifecycle

    /// Starts a break with the specified duration.
    ///
    /// - Parameter minutes: Break duration in minutes (1-5).
    /// - Throws: `BreakFlowError` if the break cannot be started.
    public func startBreak(minutes: Int) throws {
        // Validate duration
        guard minutes >= Self.minimumMinutes && minutes <= Self.maximumMinutes else {
            throw BreakFlowError.invalidDuration(minutes)
        }

        // Must have an active session
        guard sessionManager.isSessionRunning else {
            throw BreakFlowError.noActiveSession
        }

        // Can only start break from active state (not already on break, not bypassing)
        guard sessionManager.sessionStatus == .active else {
            throw BreakFlowError.invalidSessionState(sessionManager.sessionStatus.rawValue)
        }

        // Cannot start break if already on break
        guard !isBreakActive else {
            throw BreakFlowError.breakAlreadyActive
        }

        let now = dateProvider()
        let breakDurationSeconds = minutes * 60
        let endTime = now.addingTimeInterval(TimeInterval(breakDurationSeconds))

        // Freeze the session remaining time
        frozenSessionRemaining = sessionManager.remainingSeconds
        currentBreakDurationMinutes = minutes

        // Transition session to on-break (pauses the main timer)
        sessionManager.transitionToBreak()

        // Suspend blocking (preserves token config for re-apply)
        blockingService.suspendBlocking()

        // Set break state
        breakEndTime = endTime
        breakEndTriggered = false
        breakState = .active(breakEndDate: endTime, remainingSeconds: breakDurationSeconds)

        // Update shared state
        sharedStateService.setOnBreak(true)
        sessionManager.breakCount += 1

        // Persist break state for termination recovery
        persistBreakState()

        // Start Live Activity (gracefully handle disabled)
        startLiveActivity(endTime: endTime, durationMinutes: minutes)

        // Start break countdown timer
        startBreakTimer()

        onBreakStarted?()
    }

    /// Called every second by the break timer.
    internal func breakTick() {
        guard case .active(let endDate, _) = breakState else { return }

        let now = dateProvider()
        let remaining = max(Int(endDate.timeIntervalSince(now)), 0)

        if remaining <= 0 {
            endBreak()
        } else {
            breakState = .active(breakEndDate: endDate, remainingSeconds: remaining)
        }
    }

    /// Ends the break — re-applies blocking, resumes the session timer, ends Live Activity.
    private func endBreak() {
        guard !breakEndTriggered else { return }
        breakEndTriggered = true

        stopBreakTimer()

        // Calculate actual break duration for statistics
        let actualBreakDuration = TimeInterval(currentBreakDurationMinutes * 60)
        sessionManager.totalBreakDuration += actualBreakDuration

        // Re-apply blocking with the same configuration
        blockingService.reapplyBlocking()

        // End Live Activity
        endLiveActivity()

        // Clear break state
        breakState = .idle
        breakEndTime = nil
        currentBreakDurationMinutes = 0

        // Update shared state
        sharedStateService.setOnBreak(false)
        clearPersistedBreakState()

        // Resume the session timer (with the frozen remaining seconds)
        sessionManager.resumeFromBreak()

        onBreakExpired?()
    }

    // MARK: - Break Timer

    /// Starts the 1-second break countdown timer.
    private func startBreakTimer() {
        stopBreakTimer()
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.breakTick()
            }
        }
    }

    /// Stops the break countdown timer.
    private func stopBreakTimer() {
        breakTimer?.invalidate()
        breakTimer = nil
    }

    // MARK: - Background/Foreground Reconciliation

    /// Called when the app enters the background. Saves state for reconciliation.
    public func handleBackgroundEntry() {
        guard isBreakActive else { return }
        stopBreakTimer()
        persistBreakState()
    }

    /// Called when the app returns to the foreground. Reconciles break state using wall-clock time.
    public func handleForegroundEntry() {
        guard case .active(let endDate, _) = breakState else { return }

        let now = dateProvider()
        let remaining = max(Int(endDate.timeIntervalSince(now)), 0)

        if remaining <= 0 {
            // Break should have completed while in background
            endBreak()
        } else {
            // Update remaining time and restart timer
            breakState = .active(breakEndDate: endDate, remainingSeconds: remaining)
            startBreakTimer()
        }
    }

    // MARK: - Termination Recovery

    /// Recovers from app termination during a break.
    /// Called on app launch when an orphaned break state is detected.
    ///
    /// - Returns: `true` if a break state was recovered, `false` otherwise.
    @discardableResult
    public func recoverBreakState() -> Bool {
        guard let persistedData = sharedStateService.getData(forKey: SharedStateKey.breakEndTime.rawValue),
              let persisted = try? JSONDecoder().decode(PersistedBreakState.self, from: persistedData) else {
            return false
        }

        let now = dateProvider()

        if now >= persisted.breakEndTime {
            // Break has expired — restore allowed tokens and re-apply blocking
            // Must seed the blocking service with persisted tokens before reapplyBlocking(),
            // otherwise it uses nil tokens (blocking ALL apps instead of the original config).
            if let tokens = persisted.allowedTokens {
                blockingService.applyBlocking(allowedTokens: tokens)
            } else {
                blockingService.reapplyBlocking()
            }

            // Update shared state
            sharedStateService.setOnBreak(false)
            clearPersistedBreakState()

            // Clean up any orphaned Live Activities
            liveActivityService.cleanupOrphanedActivities()

            return true
        } else {
            // Break is still active — resume break countdown
            let remaining = max(Int(persisted.breakEndTime.timeIntervalSince(now)), 0)
            breakEndTime = persisted.breakEndTime
            breakEndTriggered = false
            frozenSessionRemaining = persisted.sessionRemainingSeconds
            currentBreakDurationMinutes = persisted.breakDurationMinutes
            breakState = .active(breakEndDate: persisted.breakEndTime, remainingSeconds: remaining)

            sharedStateService.setOnBreak(true)

            // Start break countdown timer
            startBreakTimer()

            return true
        }
    }

    // MARK: - Live Activity Management

    /// Starts a Live Activity for the break countdown.
    private func startLiveActivity(endTime: Date, durationMinutes: Int) {
        guard liveActivityService.areActivitiesEnabled else { return }

        let attributes = BreakActivityAttributes(
            breakDuration: TimeInterval(durationMinutes * 60),
            sessionName: "Deep Focus",
            sessionID: sessionManager.currentSessionID,
            sessionStartTime: sessionManager.sessionStartTime
        )
        let state = BreakActivityState(
            endDate: endTime,
            remainingSeconds: TimeInterval(durationMinutes * 60),
            isActive: true
        )

        do {
            liveActivityID = try liveActivityService.startBreakActivity(
                attributes: attributes,
                state: state
            )
        } catch {
            // Live Activity failed to start — break still works
            liveActivityID = nil
        }
    }

    /// Ends the current Live Activity.
    private func endLiveActivity() {
        guard let activityID = liveActivityID else { return }
        liveActivityService.endBreakActivity(id: activityID, dismissalPolicy: .immediate)
        liveActivityID = nil
    }

    /// Cleans up orphaned Live Activities from previous sessions.
    public func cleanupOrphanedActivities() {
        liveActivityService.cleanupOrphanedActivities()
    }

    // MARK: - Persistence

    /// Persists break state to UserDefaults for termination recovery.
    private func persistBreakState() {
        guard let endTime = breakEndTime,
              let sessionID = sessionManager.currentSessionID else { return }

        let state = PersistedBreakState(
            breakEndTime: endTime,
            sessionRemainingSeconds: frozenSessionRemaining,
            breakDurationMinutes: currentBreakDurationMinutes,
            sessionID: sessionID,
            allowedTokens: blockingService.currentAllowedTokens
        )

        if let data = try? JSONEncoder().encode(state) {
            sharedStateService.setData(data, forKey: SharedStateKey.breakEndTime.rawValue)
        }
    }

    /// Clears persisted break state from UserDefaults.
    private func clearPersistedBreakState() {
        sharedStateService.setData(nil, forKey: SharedStateKey.breakEndTime.rawValue)
    }

    // MARK: - Session Completion Cleanup

    /// Cleans up break state when the session completes or is abandoned.
    public func handleSessionCompleted() {
        guard isBreakActive else { return }

        stopBreakTimer()
        endLiveActivity()

        breakState = .idle
        breakEndTime = nil
        breakEndTriggered = false
        currentBreakDurationMinutes = 0

        sharedStateService.setOnBreak(false)
        clearPersistedBreakState()
    }

    // MARK: - Cleanup

    /// Resets the manager to idle state.
    public func resetToIdle() {
        stopBreakTimer()
        endLiveActivity()

        breakState = .idle
        breakEndTime = nil
        breakEndTriggered = false
        frozenSessionRemaining = 0
        currentBreakDurationMinutes = 0
        liveActivityID = nil

        sharedStateService.setOnBreak(false)
        clearPersistedBreakState()
    }
}
