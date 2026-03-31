import SwiftUI
import FocusCore

// MARK: - DurationSelectionView

/// View for selecting a deep focus session duration.
/// Shows preset duration buttons (30/60/90/120 min) and a custom input field.
/// Presets and custom input are mutually exclusive — selecting one clears the other.
/// The Start button is enabled only when a valid duration is selected.
struct DurationSelectionView: View {

    // MARK: - State

    /// The currently selected preset duration (nil if custom is being used).
    @State private var selectedPreset: Int?

    /// The custom duration input string.
    @State private var customDurationText: String = ""

    /// Whether the custom input field is active (focused).
    @FocusState private var isCustomFieldFocused: Bool

    /// Error message for invalid custom duration.
    @State private var validationError: String?

    // MARK: - Dependencies

    let sessionManager: DeepFocusSessionManager

    // MARK: - Computed Properties

    /// The resolved duration in minutes from either preset or custom input.
    private var resolvedDurationMinutes: Int? {
        if let preset = selectedPreset {
            return preset
        }
        if let custom = Int(customDurationText), DeepFocusDuration.isValid(minutes: custom) {
            return custom
        }
        return nil
    }

    /// Whether the Start button should be enabled.
    private var isStartEnabled: Bool {
        resolvedDurationMinutes != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                    .accessibilityIdentifier("DeepFocusIcon")
                Text("Deep Focus")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Choose your session duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Preset Buttons
            VStack(spacing: 12) {
                Text("Presets")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(DeepFocusDuration.presets, id: \.self) { preset in
                        Button {
                            selectPreset(preset)
                        } label: {
                            Text("\(preset) min")
                                .font(.title3)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedPreset == preset ? Color.purple : Color(.systemGray6))
                                )
                                .foregroundStyle(selectedPreset == preset ? .white : .primary)
                        }
                        .accessibilityIdentifier("PresetButton_\(preset)")
                    }
                }
            }
            .padding(.horizontal)

            // Custom Duration Input
            VStack(spacing: 8) {
                Text("Custom Duration")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    TextField("Minutes (\(DeepFocusDuration.minimumMinutes)-\(DeepFocusDuration.maximumMinutes))", text: $customDurationText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isCustomFieldFocused)
                        .accessibilityIdentifier("CustomDurationField")
                        .onChange(of: customDurationText) {
                            if !customDurationText.isEmpty {
                                selectedPreset = nil
                                validateCustomDuration()
                            }
                        }

                    Text("min")
                        .foregroundStyle(.secondary)
                }

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("ValidationError")
                }
            }
            .padding(.horizontal)

            Spacer()

            // Start Button
            Button {
                startSession()
            } label: {
                Text("Start Session")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isStartEnabled ? Color.purple : Color(.systemGray4))
                    )
                    .foregroundStyle(isStartEnabled ? .white : .secondary)
            }
            .disabled(!isStartEnabled)
            .accessibilityIdentifier("StartSessionButton")
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Actions

    private func selectPreset(_ preset: Int) {
        selectedPreset = preset
        customDurationText = ""
        validationError = nil
        isCustomFieldFocused = false
    }

    private func validateCustomDuration() {
        guard !customDurationText.isEmpty else {
            validationError = nil
            return
        }

        guard let minutes = Int(customDurationText) else {
            validationError = "Enter a valid number"
            return
        }

        if minutes < DeepFocusDuration.minimumMinutes {
            validationError = "Minimum \(DeepFocusDuration.minimumMinutes) minutes"
        } else if minutes > DeepFocusDuration.maximumMinutes {
            validationError = "Maximum \(DeepFocusDuration.maximumMinutes) minutes"
        } else {
            validationError = nil
        }
    }

    private func startSession() {
        guard let minutes = resolvedDurationMinutes else { return }

        do {
            try sessionManager.startSession(durationMinutes: minutes)
        } catch {
            validationError = error.localizedDescription
        }
    }
}
