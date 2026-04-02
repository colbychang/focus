import SwiftUI
import FocusCore

// MARK: - BreakDurationSelectionView

/// View for selecting a break duration (1-5 minutes) during an active deep focus session.
/// Shows 5 buttons for each minute option. Single select. Confirm starts the break, cancel dismisses.
struct BreakDurationSelectionView: View {

    // MARK: - State

    /// The currently selected break duration in minutes (nil if nothing selected).
    @State private var selectedMinutes: Int?

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Callbacks

    /// Called when the user confirms the break with a selected duration.
    var onConfirm: ((Int) -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("BreakIcon")

                Text("Take a Break")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("BreakTitle")

                Text("Select your break duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("BreakSubtitle")
            }
            .padding(.top, 24)

            // Duration buttons (1-5 minutes)
            VStack(spacing: 12) {
                ForEach(1...5, id: \.self) { minutes in
                    Button {
                        selectedMinutes = minutes
                    } label: {
                        HStack {
                            Text("\(minutes) minute\(minutes == 1 ? "" : "s")")
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedMinutes == minutes {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMinutes == minutes ? Color.orange.opacity(0.15) : Color(.systemGray6))
                        )
                        .foregroundStyle(selectedMinutes == minutes ? .orange : .primary)
                    }
                    .accessibilityIdentifier("BreakDurationButton_\(minutes)")
                }
            }
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    if let minutes = selectedMinutes {
                        onConfirm?(minutes)
                        dismiss()
                    }
                } label: {
                    Text("Start Break")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedMinutes != nil ? Color.orange : Color(.systemGray4))
                        )
                        .foregroundStyle(selectedMinutes != nil ? .white : .secondary)
                }
                .disabled(selectedMinutes == nil)
                .accessibilityIdentifier("ConfirmBreakButton")

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("CancelBreakButton")
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
