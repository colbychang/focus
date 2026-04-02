import SwiftUI
import SwiftData
import FocusCore

// MARK: - DeepFocusTabView

/// View for the Deep Focus tab.
/// Shows duration selection when idle, or the launcher view when a session is running.
/// The launcher view displays only allowed apps grouped by category with the session timer.
///
/// Orchestrates session lifecycle events:
/// - Session completion (timer reaches 0): records stats, clears blocking, ends Live Activity
/// - Session exit (user confirms two-step dialog): records abandoned session, clears blocking
struct DeepFocusTabView: View {
    let sessionManager: DeepFocusSessionManager
    let blockingService: DeepFocusBlockingService
    var breakFlowManager: BreakFlowManager?
    var bypassFlowManager: BypassFlowManager?

    /// The session recorder for persisting session stats to SwiftData.
    private let sessionRecorder = DeepFocusSessionRecorder()

    @Environment(\.modelContext) private var modelContext

    /// The allowed apps configuration for the current session.
    @State private var allowedAppsConfig: AllowedAppsConfig = AllowedAppsConfig()

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.isSessionRunning {
                    DeepFocusLauncherView(
                        sessionManager: sessionManager,
                        categoryGroups: AppCategoryGrouper.group(config: allowedAppsConfig),
                        breakFlowManager: breakFlowManager,
                        onSessionExitConfirmed: {
                            handleSessionExit()
                        }
                    )
                } else if sessionManager.sessionStatus == .completed {
                    // Show completion briefly, then reset
                    DeepFocusCompletionView(sessionManager: sessionManager)
                } else {
                    DurationSelectionView(
                        sessionManager: sessionManager,
                        blockingService: blockingService,
                        onSessionStarted: { config in
                            allowedAppsConfig = config
                        }
                    )
                }
            }
            .navigationTitle("Deep Focus")
        }
        .accessibilityIdentifier("DeepFocusTabContent")
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            sessionManager.handleBackgroundEntry()
            breakFlowManager?.handleBackgroundEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            breakFlowManager?.handleForegroundEntry()
            sessionManager.handleForegroundEntry()
        }
        .onChange(of: sessionManager.sessionStatus) { _, newStatus in
            // Clear blocking when session ends (completed or abandoned)
            if newStatus == .completed || newStatus == .abandoned {
                blockingService.clearBlocking()
                allowedAppsConfig = AllowedAppsConfig()
            }
        }
        .task {
            // Wire up session completion callback for recording stats
            sessionManager.onSessionCompleted = {
                handleSessionCompletion()
            }
        }
    }

    // MARK: - Session Lifecycle Handlers

    /// Handles session completion (timer reached 0).
    /// Cleans up bypass/break flows, ends Live Activity, records stats.
    private func handleSessionCompletion() {
        // Clean up sub-flows
        bypassFlowManager?.handleSessionCompleted()
        breakFlowManager?.handleSessionCompleted()

        // Record completed session stats to SwiftData
        sessionRecorder.recordSession(from: sessionManager, modelContext: modelContext)
    }

    /// Handles user-confirmed session exit (two-step confirmation completed).
    /// Abandons session, cleans up sub-flows, records abandoned stats.
    private func handleSessionExit() {
        // Clean up sub-flows first
        bypassFlowManager?.handleSessionCompleted()
        breakFlowManager?.handleSessionCompleted()

        // Abandon the session (sets status to .abandoned, clears shared state)
        sessionManager.abandonSession()

        // Record abandoned session stats to SwiftData
        sessionRecorder.recordSession(from: sessionManager, modelContext: modelContext)

        // Reset to idle
        sessionManager.resetToIdle()
    }
}

// MARK: - DeepFocusCompletionView

/// Brief completion view shown when a session finishes.
struct DeepFocusCompletionView: View {
    let sessionManager: DeepFocusSessionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .accessibilityIdentifier("CompletionIcon")

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.semibold)

            Text("Great work staying focused.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                sessionManager.resetToIdle()
            } label: {
                Text("Done")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple)
                    )
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("DoneButton")
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}
