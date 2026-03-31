import SwiftUI
import FocusCore

// MARK: - DeepFocusTabView

/// View for the Deep Focus tab.
/// Shows duration selection when idle, or the launcher view when a session is running.
/// The launcher view displays only allowed apps grouped by category with the session timer.
struct DeepFocusTabView: View {
    let sessionManager: DeepFocusSessionManager
    let blockingService: DeepFocusBlockingService

    /// The allowed apps configuration for the current session.
    @State private var allowedAppsConfig: AllowedAppsConfig = AllowedAppsConfig()

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.isSessionRunning {
                    DeepFocusLauncherView(
                        sessionManager: sessionManager,
                        categoryGroups: AppCategoryGrouper.group(config: allowedAppsConfig)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            sessionManager.handleForegroundEntry()
        }
        .onChange(of: sessionManager.sessionStatus) { _, newStatus in
            // Clear blocking when session ends (completed or abandoned)
            if newStatus == .completed || newStatus == .abandoned {
                blockingService.clearBlocking()
                allowedAppsConfig = AllowedAppsConfig()
            }
        }
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
