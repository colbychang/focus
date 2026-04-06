import SwiftUI
import FocusCore

// MARK: - SessionHistoryView

/// Displays a list of all sessions (focus mode + deep focus) sorted by startDate descending.
/// Each row shows date, duration, mode type, and status badge.
struct SessionHistoryView: View {
    let sessions: [DeepFocusSession]

    var body: some View {
        if sessions.isEmpty {
            ContentUnavailableView(
                "No Sessions",
                systemImage: "clock.arrow.circlepath",
                description: Text("Your session history will appear here.")
            )
            .accessibilityIdentifier("SessionHistoryEmpty")
        } else {
            List {
                ForEach(sessions, id: \.id) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionHistoryRowView(session: session)
                    }
                    .accessibilityIdentifier("SessionRow_\(session.id.uuidString)")
                }
            }
            .accessibilityIdentifier("SessionHistoryList")
        }
    }
}

// MARK: - SessionHistoryRowView

/// A single row in the session history list.
/// Shows date, duration, mode type, and status badge.
struct SessionHistoryRowView: View {
    let session: DeepFocusSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(DashboardViewModel.formatSessionDate(session.startTime))
                    .font(.body)
                    .accessibilityIdentifier("SessionRowDate")

                HStack(spacing: 8) {
                    Text(DashboardViewModel.formatDuration(session.configuredDuration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("SessionRowDuration")

                    Text(DashboardViewModel.modeTypeLabel(for: session))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("SessionRowModeType")
                }
            }

            Spacer()

            SessionStatusBadge(status: session.status)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SessionStatusBadge

/// A colored badge indicating the session status.
struct SessionStatusBadge: View {
    let status: SessionStatus

    private var info: (label: String, colorName: String) {
        DashboardViewModel.statusInfo(for: status)
    }

    private var color: Color {
        switch info.colorName {
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .gray
        }
    }

    var body: some View {
        Text(info.label)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .accessibilityIdentifier("SessionStatusBadge")
    }
}
