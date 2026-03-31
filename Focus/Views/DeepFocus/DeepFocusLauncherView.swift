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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Timer header
            timerHeader

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

    // MARK: - Session Controls

    private var sessionControls: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                sessionManager.abandonSession()
                sessionManager.resetToIdle()
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
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }

    // MARK: - Computed Properties

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
