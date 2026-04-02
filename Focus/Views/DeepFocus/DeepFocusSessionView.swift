import SwiftUI
import FocusCore

// MARK: - DeepFocusSessionView

/// View displayed during an active deep focus session.
/// Shows the countdown timer, session status, and controls.
struct DeepFocusSessionView: View {

    // MARK: - Dependencies

    let sessionManager: DeepFocusSessionManager

    /// Callback invoked when the user confirms session exit through the two-step dialog.
    var onSessionExitConfirmed: (() -> Void)?

    // MARK: - State

    @State private var showingFirstExitConfirmation = false
    @State private var showingSecondExitConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Status indicator
            statusBadge

            // Timer display
            Text(sessionManager.formattedTimeRemaining)
                .font(.system(size: 72, weight: .light, design: .monospaced))
                .foregroundStyle(timerColor)
                .accessibilityIdentifier("TimerDisplay")

            // Session info
            if let startTime = sessionManager.sessionStartTime {
                Text("Started at \(startTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("SessionStartTime")
            }

            Spacer()

            // Session controls
            VStack(spacing: 12) {
                // End Session button
                Button(role: .destructive) {
                    showingFirstExitConfirmation = true
                } label: {
                    Text("End Session")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityIdentifier("EndSessionButton")
                .alert("End Session?", isPresented: $showingFirstExitConfirmation) {
                    Button("Cancel", role: .cancel) { }
                        .accessibilityIdentifier("FirstExitCancelButton")
                    Button("End Session", role: .destructive) {
                        showingSecondExitConfirmation = true
                    }
                    .accessibilityIdentifier("FirstExitConfirmButton")
                } message: {
                    Text("Are you sure you want to end this session?")
                }
                .alert("Lose Focus Time?", isPresented: $showingSecondExitConfirmation) {
                    Button("Cancel", role: .cancel) { }
                        .accessibilityIdentifier("SecondExitCancelButton")
                    Button("End Session", role: .destructive) {
                        onSessionExitConfirmed?()
                    }
                    .accessibilityIdentifier("SecondExitConfirmButton")
                } message: {
                    Text("You will lose \(accumulatedMinutes) minutes of accumulated focus time. This cannot be undone.")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
        .accessibilityIdentifier("SessionStatusBadge")
    }

    // MARK: - Computed Properties

    private var statusText: String {
        switch sessionManager.sessionStatus {
        case .active:
            return "Focusing"
        case .onBreak:
            return "On Break"
        case .bypassing:
            return "Bypass Active"
        case .completed:
            return "Completed"
        case .abandoned:
            return "Ended"
        case .idle:
            return "Ready"
        }
    }

    private var statusColor: Color {
        switch sessionManager.sessionStatus {
        case .active:
            return .green
        case .onBreak:
            return .orange
        case .bypassing:
            return .yellow
        case .completed:
            return .blue
        case .abandoned, .idle:
            return .gray
        }
    }

    /// Computes the accumulated focus minutes for the warning dialog.
    private var accumulatedMinutes: Int {
        let elapsedSeconds = sessionManager.configuredDurationSeconds - sessionManager.remainingSeconds
        return max(elapsedSeconds / 60, 0)
    }

    private var timerColor: Color {
        if sessionManager.remainingSeconds <= 60 {
            return .red
        } else if sessionManager.remainingSeconds <= 300 {
            return .orange
        } else {
            return .primary
        }
    }
}
