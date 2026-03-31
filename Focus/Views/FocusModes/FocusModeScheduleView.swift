import SwiftUI
import FocusCore

// MARK: - FocusModeScheduleView

/// Schedule configuration section for focus mode profiles.
/// Includes day-of-week multi-select, time pickers for start/end,
/// overnight schedule indicator, and overlap warning display.
struct FocusModeScheduleView: View {
    @Bindable var viewModel: FocusModeFormViewModel

    var body: some View {
        // MARK: Enable/Disable Toggle
        Section {
            Toggle("Enable Schedule", isOn: $viewModel.isScheduleEnabled)
                .accessibilityIdentifier("ScheduleToggle")
                .onChange(of: viewModel.isScheduleEnabled) { _, _ in
                    viewModel.checkForOverlaps()
                }
        } header: {
            Text("Schedule")
        } footer: {
            if viewModel.isScheduleEnabled {
                Text("Set a recurring schedule to automatically activate this focus mode.")
            }
        }

        if viewModel.isScheduleEnabled {
            // MARK: Day Selection
            Section {
                daySelector
            } header: {
                Text("Days")
            }

            // MARK: Time Selection
            Section {
                DatePicker(
                    "Start Time",
                    selection: $viewModel.scheduleStartTime,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityIdentifier("StartTimePicker")
                .onChange(of: viewModel.scheduleStartTime) { _, _ in
                    viewModel.checkForOverlaps()
                }

                DatePicker(
                    "End Time",
                    selection: $viewModel.scheduleEndTime,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityIdentifier("EndTimePicker")
                .onChange(of: viewModel.scheduleEndTime) { _, _ in
                    viewModel.checkForOverlaps()
                }

                if viewModel.isOvernightSchedule {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(.indigo)
                        Text("Overnight schedule (crosses midnight)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("OvernightIndicator")
                }
            } header: {
                Text("Time")
            }

            // MARK: Overlap Warnings
            if !viewModel.scheduleConflicts.isEmpty {
                Section {
                    ForEach(Array(viewModel.scheduleConflicts.enumerated()), id: \.offset) { index, conflict in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Overlaps with \"\(conflict.profileName2)\"")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(conflict.overlappingDays.map(\.shortName).joined(separator: ", ")) · \(conflict.timeDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("OverlapWarning_\(index)")
                    }
                } header: {
                    Text("Schedule Conflicts")
                }
            }

            // MARK: Schedule Error
            if let scheduleError = viewModel.scheduleErrorMessage {
                Section {
                    Text(scheduleError)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .accessibilityIdentifier("ScheduleErrorMessage")
                }
            }
        }
    }

    // MARK: - Day Selector

    private var daySelector: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(Weekday.orderedForDisplay) { day in
                Button {
                    viewModel.toggleDay(day)
                } label: {
                    Text(day.shortName)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            viewModel.scheduleDays.contains(day)
                                ? Color.accentColor
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(
                            viewModel.scheduleDays.contains(day)
                                ? .white
                                : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("DayButton_\(day.shortName)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("DaySelector")
    }
}
