import Foundation

// MARK: - BypassFlowError

/// Errors that can occur during bypass flow operations.
public enum BypassFlowError: Error, LocalizedError, Equatable {
    /// Cannot request bypass while on break (already have full access).
    case bypassDuringBreakRejected
    /// No active deep focus session to bypass.
    case noActiveSession
    /// Bypass countdown is already running (use cancelBypass first or let replacement happen).
    case countdownAlreadyActive

    public var errorDescription: String? {
        switch self {
        case .bypassDuringBreakRejected:
            return "Cannot request bypass during break — you already have full access"
        case .noActiveSession:
            return "No active deep focus session"
        case .countdownAlreadyActive:
            return "A bypass countdown is already running"
        }
    }
}

// MARK: - BypassState

/// The current state of the bypass flow.
public enum BypassState: Equatable, Sendable {
    /// No bypass active.
    case idle
    /// Countdown is running for the given app token. Seconds remaining in countdown.
    case countdown(appTokenData: Data, secondsRemaining: Int)
    /// Bypass is active — the specified app is unlocked.
    case active(appTokenData: Data)
}

// MARK: - BypassFlowManager

/// Manages the bypass flow for accessing blocked apps during deep focus.
///
/// Flow:
/// 1. User requests bypass for a blocked app → 60-second countdown starts
/// 2. During countdown, the app remains blocked (no skip, no fast-forward)
/// 3. After countdown completes, only the requested app is added to the exception set
/// 4. Cancel dismisses the countdown
/// 5. New bypass request during active countdown cancels old, starts fresh 60s for new app
/// 6. Previous bypass is revoked when a new bypass completes
/// 7. Main deep focus timer continues during bypass (not paused)
/// 8. Bypass during break is rejected (already have full access)
/// 9. Break during bypass countdown cancels bypass; break with active bypass revokes it
/// 10. Session completion cleans up all bypass state
@MainActor
@Observable
public final class BypassFlowManager {

    // MARK: - Constants

    /// Duration of the bypass countdown in seconds.
    public static let countdownDuration: Int = 60

    // MARK: - Published State

    /// The current bypass state.
    public private(set) var bypassState: BypassState = .idle

    /// The number of seconds remaining in the countdown (0 if not counting down).
    public var countdownSecondsRemaining: Int {
        switch bypassState {
        case .countdown(_, let seconds):
            return seconds
        case .idle, .active:
            return 0
        }
    }

    /// Whether a countdown is currently active.
    public var isCountdownActive: Bool {
        if case .countdown = bypassState { return true }
        return false
    }

    /// Whether a bypass is currently active (app is unlocked).
    public var isBypassActive: Bool {
        if case .active = bypassState { return true }
        return false
    }

    /// The app token data that is currently bypassed (or being counted down for).
    public var currentAppTokenData: Data? {
        switch bypassState {
        case .countdown(let data, _):
            return data
        case .active(let data):
            return data
        case .idle:
            return nil
        }
    }

    // MARK: - Private State

    /// Timer for the 1-second countdown ticks.
    private var countdownTimer: Timer?

    /// Wall-clock timestamp when the countdown started (for background reconciliation).
    private var countdownStartTimestamp: Date?

    /// Flag to prevent duplicate completion handling.
    private var countdownCompletionTriggered: Bool = false

    /// Token data of the previously bypassed app (for revocation when new bypass completes).
    private var previousBypassedAppTokenData: Data?

    // MARK: - Callbacks

    /// Called when the bypass countdown completes and the app should be unlocked.
    /// Parameter: token data of the app to unlock.
    public var onBypassGranted: ((Data) -> Void)?

    /// Called when a bypass is revoked (new bypass replaces old, break cancels, session ends).
    /// Parameter: token data of the app whose bypass was revoked.
    public var onBypassRevoked: ((Data) -> Void)?

    /// Called when a countdown is cancelled.
    public var onCountdownCancelled: (() -> Void)?

    // MARK: - Dependencies

    private let blockingService: DeepFocusBlockingService
    private let sessionManager: DeepFocusSessionManager
    private let sharedStateService: SharedStateService
    private let dateProvider: () -> Date

    // MARK: - Initialization

    /// Creates a BypassFlowManager with the given dependencies.
    ///
    /// - Parameters:
    ///   - blockingService: The blocking service for managing shield exceptions.
    ///   - sessionManager: The session manager for state machine transitions.
    ///   - sharedStateService: The shared state service for cross-extension persistence.
    ///   - dateProvider: Closure returning the current date (injectable for testing).
    public init(
        blockingService: DeepFocusBlockingService,
        sessionManager: DeepFocusSessionManager,
        sharedStateService: SharedStateService,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.blockingService = blockingService
        self.sessionManager = sessionManager
        self.sharedStateService = sharedStateService
        self.dateProvider = dateProvider
    }

    // MARK: - Bypass Request

    /// Requests bypass access for a specific blocked app.
    ///
    /// - Parameter appTokenData: The serialized token data of the app to bypass.
    /// - Throws: `BypassFlowError.bypassDuringBreakRejected` if currently on break,
    ///           `BypassFlowError.noActiveSession` if no session is running.
    ///
    /// If a countdown is already running, the old countdown is cancelled and a new
    /// 60-second countdown starts for the new app.
    /// If a bypass is currently active (an app is unlocked), the new countdown starts
    /// and the old bypass will be revoked when the new one completes.
    public func requestBypass(forApp appTokenData: Data) throws {
        // Cannot bypass during break — already have full access
        guard sessionManager.sessionStatus != .onBreak else {
            throw BypassFlowError.bypassDuringBreakRejected
        }

        // Must have an active-like session (active or bypassing)
        guard sessionManager.sessionStatus == .active || sessionManager.sessionStatus == .bypassing else {
            throw BypassFlowError.noActiveSession
        }

        // If a countdown is already running, cancel it (replacement)
        if isCountdownActive {
            stopCountdownTimer()
        }

        // If a bypass is currently active, track the old app for revocation on new completion
        if case .active(let oldAppTokenData) = bypassState {
            previousBypassedAppTokenData = oldAppTokenData
        }

        // Start fresh 60-second countdown
        countdownCompletionTriggered = false
        countdownStartTimestamp = dateProvider()
        bypassState = .countdown(appTokenData: appTokenData, secondsRemaining: Self.countdownDuration)

        // Transition session to bypassing state if not already
        if sessionManager.sessionStatus == .active {
            sessionManager.transitionToBypassing()
        }

        // Persist bypass state
        sharedStateService.setBypassActive(true)

        // Start the timer
        startCountdownTimer()
    }

    // MARK: - Cancel

    /// Cancels the current bypass countdown or revokes an active bypass.
    public func cancelBypass() {
        switch bypassState {
        case .countdown:
            stopCountdownTimer()
            bypassState = .idle
            countdownStartTimestamp = nil
            sharedStateService.setBypassActive(false)

            // Resume to active state
            if sessionManager.sessionStatus == .bypassing {
                sessionManager.resumeFromBypassing()
            }

            onCountdownCancelled?()

        case .active(let appTokenData):
            // Revoke the bypass
            revokeBypass(appTokenData: appTokenData)

        case .idle:
            break
        }
    }

    // MARK: - Break Interaction

    /// Called when a break starts during a bypass.
    /// - If countdown is running: cancels the countdown.
    /// - If bypass is active: revokes the bypass.
    public func handleBreakStarted() {
        switch bypassState {
        case .countdown:
            stopCountdownTimer()
            bypassState = .idle
            countdownStartTimestamp = nil
            sharedStateService.setBypassActive(false)
            onCountdownCancelled?()

        case .active(let appTokenData):
            revokeBypass(appTokenData: appTokenData)

        case .idle:
            break
        }
    }

    // MARK: - Session Completion Cleanup

    /// Cleans up all bypass state when the session completes or is abandoned.
    /// Cancels any countdown, revokes any active bypass, and clears all state.
    public func handleSessionCompleted() {
        switch bypassState {
        case .countdown:
            stopCountdownTimer()
            bypassState = .idle
            countdownStartTimestamp = nil
            sharedStateService.setBypassActive(false)

        case .active(let appTokenData):
            // Revoke bypass silently (session is ending)
            stopCountdownTimer()
            bypassState = .idle
            sharedStateService.setBypassActive(false)
            onBypassRevoked?(appTokenData)

        case .idle:
            break
        }

        countdownCompletionTriggered = false
        previousBypassedAppTokenData = nil
    }

    // MARK: - Background/Foreground Reconciliation

    /// Called when the app enters the background. Records the current timestamp for reconciliation.
    public func handleBackgroundEntry() {
        // No special action needed — wall-clock reconciliation uses countdownStartTimestamp
        stopCountdownTimer()
    }

    /// Called when the app returns to the foreground. Reconciles the countdown using wall-clock time.
    public func handleForegroundEntry() {
        guard case .countdown(let appTokenData, _) = bypassState,
              let startTimestamp = countdownStartTimestamp else {
            return
        }

        let now = dateProvider()
        let elapsedSinceStart = Int(now.timeIntervalSince(startTimestamp))
        let remaining = max(Self.countdownDuration - elapsedSinceStart, 0)

        if remaining <= 0 {
            // Countdown should have completed while in background
            completeCountdown(appTokenData: appTokenData)
        } else {
            // Update remaining time and restart timer
            bypassState = .countdown(appTokenData: appTokenData, secondsRemaining: remaining)
            startCountdownTimer()
        }
    }

    // MARK: - Countdown Timer

    /// Starts the 1-second countdown timer.
    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.countdownTick()
            }
        }
    }

    /// Stops the countdown timer.
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Called every second by the countdown timer.
    internal func countdownTick() {
        guard case .countdown(let appTokenData, let secondsRemaining) = bypassState else {
            return
        }

        let newRemaining = max(secondsRemaining - 1, 0)

        if newRemaining <= 0 {
            completeCountdown(appTokenData: appTokenData)
        } else {
            bypassState = .countdown(appTokenData: appTokenData, secondsRemaining: newRemaining)
        }
    }

    // MARK: - Countdown Completion

    /// Completes the countdown — grants bypass access for the requested app.
    private func completeCountdown(appTokenData: Data) {
        guard !countdownCompletionTriggered else { return }
        countdownCompletionTriggered = true

        stopCountdownTimer()

        // If there was a previous active bypass, revoke it first
        if let oldAppTokenData = previousBypassedAppTokenData, oldAppTokenData != appTokenData {
            removeAppFromExceptions(appTokenData: oldAppTokenData)
            onBypassRevoked?(oldAppTokenData)
            previousBypassedAppTokenData = nil
        }

        // Add the new app to the exception set
        addAppToExceptions(appTokenData: appTokenData)

        // Transition to active bypass
        bypassState = .active(appTokenData: appTokenData)
        countdownStartTimestamp = nil

        // Increment bypass count on session manager
        sessionManager.bypassCount += 1

        // Keep session in bypassing state (timer continues)
        sharedStateService.setBypassActive(true)

        onBypassGranted?(appTokenData)
    }

    // MARK: - Bypass Revocation

    /// Revokes an active bypass by removing the app from the exception set.
    private func revokeBypass(appTokenData: Data) {
        stopCountdownTimer()

        // Remove the app from the exception set
        removeAppFromExceptions(appTokenData: appTokenData)

        bypassState = .idle
        countdownStartTimestamp = nil
        sharedStateService.setBypassActive(false)

        // Resume to active state
        if sessionManager.sessionStatus == .bypassing {
            sessionManager.resumeFromBypassing()
        }

        onBypassRevoked?(appTokenData)
    }

    // MARK: - Shield Exception Management

    /// Adds a single app to the ManagedSettingsStore exception set.
    /// This is done by re-applying shields with the app added to the allowed tokens.
    private func addAppToExceptions(appTokenData: Data) {
        var tokens = blockingService.currentAllowedTokens ?? Set<Data>()
        tokens.insert(appTokenData)
        blockingService.applyBlocking(allowedTokens: tokens)
    }

    /// Removes a single app from the ManagedSettingsStore exception set.
    /// This restores blocking for that specific app.
    private func removeAppFromExceptions(appTokenData: Data) {
        var tokens = blockingService.currentAllowedTokens ?? Set<Data>()
        tokens.remove(appTokenData)
        blockingService.applyBlocking(allowedTokens: tokens)
    }

    // MARK: - Cleanup

    /// Resets the manager to idle state.
    public func resetToIdle() {
        stopCountdownTimer()
        bypassState = .idle
        countdownStartTimestamp = nil
        countdownCompletionTriggered = false
        previousBypassedAppTokenData = nil
        sharedStateService.setBypassActive(false)
    }
}
