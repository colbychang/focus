import SwiftUI
import FocusCore

// MARK: - SessionDetailView

/// Detailed view for a single session.
/// Shows: start/end time, duration formatted, mode type, status,
/// and deep focus metadata (bypasses, breaks).
struct SessionDetailView: View {
    let session: DeepFocusSession

    /// Computed end time: start time + configured duration for completed sessions,
    /// or start time + elapsed time for abandoned sessions.
    private var endTime: Date? {
        switch session.status {
        case .completed:
            return session.startTime.addingTimeInterval(session.configuredDuration + session.totalBreakDuration)
        case .abandoned:
            let elapsed = session.configuredDuration - session.remainingSeconds
            return session.startTime.addingTimeInterval(elapsed + session.totalBreakDuration)
        default:
            return nil
        }
    }

    var body: some View {
        List {
            // MARK: Session Info
            Section("Session Info") {
                DetailRow(
                    label: "Status",
                    value: DashboardViewModel.statusInfo(for: session.status).label,
                    accessibilityID: "DetailStatus"
                )

                DetailRow(
                    label: "Mode Type",
                    value: DashboardViewModel.modeTypeLabel(for: session),
                    accessibilityID: "DetailModeType"
                )

                DetailRow(
                    label: "Duration",
                    value: DashboardViewModel.formatDurationDetailed(session.configuredDuration),
                    accessibilityID: "DetailDuration"
                )
            }

            // MARK: Timing
            Section("Timing") {
                DetailRow(
                    label: "Start Time",
                    value: formatDateTime(session.startTime),
                    accessibilityID: "DetailStartTime"
                )

                if let end = endTime {
                    DetailRow(
                        label: "End Time",
                        value: formatDateTime(end),
                        accessibilityID: "DetailEndTime"
                    )
                }
            }

            // MARK: Deep Focus Metadata
            Section("Deep Focus Metadata") {
                DetailRow(
                    label: "Bypasses",
                    value: "\(session.bypassCount)",
                    accessibilityID: "DetailBypasses"
                )

                DetailRow(
                    label: "Breaks",
                    value: "\(session.breakCount)",
                    accessibilityID: "DetailBreaks"
                )

                if session.totalBreakDuration > 0 {
                    DetailRow(
                        label: "Total Break Time",
                        value: DashboardViewModel.formatDuration(session.totalBreakDuration),
                        accessibilityID: "DetailTotalBreakTime"
                    )
                }
            }
        }
        .navigationTitle("Session Detail")
        .accessibilityIdentifier("SessionDetailView")
    }

    // MARK: - Formatting

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - DetailRow

/// A single row in the session detail list with label and value.
struct DetailRow: View {
    let label: String
    let value: String
    let accessibilityID: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
