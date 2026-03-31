import SwiftUI
import FocusCore

// MARK: - DeepFocusTabView

/// View for the Deep Focus tab.
/// Shows duration selection when idle, or the active session view when a session is running.
struct DeepFocusTabView: View {
    let sessionManager: DeepFocusSessionManager

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.isSessionRunning {
                    DeepFocusSessionView(sessionManager: sessionManager)
                } else if sessionManager.sessionStatus == .completed {
                    // Show completion briefly, then reset
                    DeepFocusCompletionView(sessionManager: sessionManager)
                } else {
                    DurationSelectionView(sessionManager: sessionManager)
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
