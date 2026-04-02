import SwiftUI
import FocusCore

// MARK: - DeepFocusLauncherView

/// Full-screen launcher view displayed during an active deep focus session.
/// Shows only the allowed apps grouped by category (Communication, Work, Music, Other).
/// Empty categories are hidden. An empty allowed-apps list shows a message.
/// Each app shows an icon and name using an opaque token Label representation.
struct DeepFocusLauncherView: View {

    // MARK: - Dependencies

    let sessionManager: DeepFocusSessionManager
    let categoryGroups: [CategoryGroup]
    var breakFlowManager: BreakFlowManager?

    /// Callback invoked when the user confirms session exit through the two-step dialog.
    var onSessionExitConfirmed: (() -> Void)?

    // MARK: - State

    @State private var showingBreakSheet = false
    @State private var showingFirstExitConfirmation = false
    @State private var showingSecondExitConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Timer header
            timerHeader

            // Break indicator (shown when on break)
            if sessionManager.sessionStatus == .onBreak, let breakManager = breakFlowManager {
                breakIndicator(breakManager: breakManager)
            }

            // Content area
            if categoryGroups.isEmpty {
                emptyStateView
            } else {
                appGridView
            }

            // Session controls
            sessionControls
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DeepFocusLauncherView")
        .sheet(isPresented: $showingBreakSheet) {
            BreakDurationSelectionView { minutes in
                try? breakFlowManager?.startBreak(minutes: minutes)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Timer Header

    private var timerHeader: some View {
        VStack(spacing: 4) {
            Text(sessionManager.formattedTimeRemaining)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(timerColor)
                .accessibilityIdentifier("LauncherTimerDisplay")

            Text("Deep Focus Session")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "app.dashed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("EmptyLauncherIcon")

            Text("No Allowed Apps")
                .font(.title3)
                .fontWeight(.medium)
                .accessibilityIdentifier("EmptyLauncherTitle")

            Text("All apps are blocked during this session.\nFocus on your work!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("EmptyLauncherMessage")

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("EmptyLauncherState")
    }

    // MARK: - App Grid

    private var appGridView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(categoryGroups, id: \.category) { group in
                    categorySection(for: group)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .accessibilityIdentifier("LauncherAppGrid")
    }

    private func categorySection(for group: CategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: group.category.iconName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(group.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("CategoryHeader_\(group.category.rawValue)")

            // App grid
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 72), spacing: 16)
            ], spacing: 16) {
                ForEach(group.apps, id: \.tokenData) { app in
                    appItem(for: app)
                }
            }
        }
    }

    private func appItem(for app: AllowedApp) -> some View {
        VStack(spacing: 6) {
            // App icon (opaque token representation)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                )
                .accessibilityIdentifier("AppIcon_\(app.displayName)")

            // App name
            Text(app.displayName)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
                .accessibilityIdentifier("AppName_\(app.displayName)")
        }
    }

    // MARK: - Break Indicator

    private func breakIndicator(breakManager: BreakFlowManager) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.orange)
                Text("Break Time")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            if let endDate = breakManager.breakEndDate {
                Text(timerInterval: Date.now...endDate, countsDown: true)
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("BreakIndicator")
    }

    // MARK: - Session Controls

    private var sessionControls: some View {
        VStack(spacing: 12) {
            // Take a Break button (only when session is active, not on break)
            if sessionManager.sessionStatus == .active && breakFlowManager != nil {
                Button {
                    showingBreakSheet = true
                } label: {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("Take a Break")
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .accessibilityIdentifier("TakeBreakButton")
            }

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
            .accessibilityIdentifier("LauncherEndSessionButton")
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

    // MARK: - Computed Properties

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
