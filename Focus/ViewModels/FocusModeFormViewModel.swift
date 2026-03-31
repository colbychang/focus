import Foundation
import SwiftData
import FocusCore

// MARK: - FocusModeFormViewModel

/// ViewModel for the focus mode create/edit form.
/// Handles form state, validation, and save operations.
@MainActor
@Observable
final class FocusModeFormViewModel {

    // MARK: - Form State

    /// The profile name entered by the user.
    var name: String = ""

    /// The selected SF Symbol name for the icon.
    var iconName: String = "moon.fill"

    /// The selected hex color string.
    var colorHex: String = "#4A90D9"

    /// Error message to display if validation or save fails.
    var errorMessage: String?

    /// Whether a save operation is in progress.
    private(set) var isSaving: Bool = false

    /// Whether the form was saved successfully (triggers dismiss).
    private(set) var didSave: Bool = false

    // MARK: - Schedule State

    /// Selected days of the week for the schedule.
    var scheduleDays: Set<Weekday> = []

    /// Schedule start time (hour and minute).
    var scheduleStartTime: Date = Calendar.current.date(
        from: DateComponents(hour: 9, minute: 0)
    ) ?? Date()

    /// Schedule end time (hour and minute).
    var scheduleEndTime: Date = Calendar.current.date(
        from: DateComponents(hour: 17, minute: 0)
    ) ?? Date()

    /// Whether the schedule section is expanded/visible.
    var isScheduleEnabled: Bool = false

    /// Schedule-related error message.
    var scheduleErrorMessage: String?

    /// Detected schedule conflicts with other profiles.
    private(set) var scheduleConflicts: [ScheduleConflict] = []

    // MARK: - Edit Mode

    /// The ID of the profile being edited (nil for create mode).
    let editingProfileId: UUID?

    /// Whether this form is in edit mode.
    var isEditing: Bool { editingProfileId != nil }

    // MARK: - Dependencies

    private let service: FocusModeService
    private let overlapDetector = ScheduleOverlapDetector()

    // MARK: - Initialization

    /// Creates a form ViewModel in create mode.
    ///
    /// - Parameter service: The focus mode service for CRUD operations.
    init(service: FocusModeService) {
        self.service = service
        self.editingProfileId = nil
    }

    /// Creates a form ViewModel in edit mode, pre-populated with the given profile's data.
    ///
    /// - Parameters:
    ///   - service: The focus mode service for CRUD operations.
    ///   - profile: The profile to edit.
    init(service: FocusModeService, profile: FocusMode) {
        self.service = service
        self.editingProfileId = profile.id
        self.name = profile.name
        self.iconName = profile.iconName
        self.colorHex = profile.colorHex

        // Load schedule data from profile
        let days = profile.scheduleDays.compactMap { Weekday(dayNumber: $0) }
        if !days.isEmpty {
            self.isScheduleEnabled = true
            self.scheduleDays = Set(days)
            self.scheduleStartTime = Calendar.current.date(
                from: DateComponents(hour: profile.scheduleStartHour, minute: profile.scheduleStartMinute)
            ) ?? Date()
            self.scheduleEndTime = Calendar.current.date(
                from: DateComponents(hour: profile.scheduleEndHour, minute: profile.scheduleEndMinute)
            ) ?? Date()
        }
    }

    // MARK: - Available Options

    /// Available SF Symbols for the icon picker.
    static let availableIcons: [String] = [
        "moon.fill", "sun.max.fill", "star.fill", "bolt.fill",
        "flame.fill", "leaf.fill", "heart.fill", "book.fill",
        "pencil", "briefcase.fill", "graduationcap.fill", "music.note",
        "gamecontroller.fill", "figure.walk", "bed.double.fill", "cup.and.saucer.fill",
        "desktopcomputer", "paintbrush.fill", "camera.fill", "airplane"
    ]

    /// Available colors for the color picker.
    static let availableColors: [String] = [
        "#4A90D9", "#E74C3C", "#2ECC71", "#F39C12",
        "#9B59B6", "#1ABC9C", "#E67E22", "#3498DB",
        "#FF6B6B", "#48C9B0", "#F7DC6F", "#BB8FCE"
    ]

    // MARK: - Schedule Helpers

    /// Start hour extracted from the scheduleStartTime date.
    var startHour: Int {
        Calendar.current.component(.hour, from: scheduleStartTime)
    }

    /// Start minute extracted from the scheduleStartTime date.
    var startMinute: Int {
        Calendar.current.component(.minute, from: scheduleStartTime)
    }

    /// End hour extracted from the scheduleEndTime date.
    var endHour: Int {
        Calendar.current.component(.hour, from: scheduleEndTime)
    }

    /// End minute extracted from the scheduleEndTime date.
    var endMinute: Int {
        Calendar.current.component(.minute, from: scheduleEndTime)
    }

    /// Whether the current schedule represents an overnight schedule (crosses midnight).
    var isOvernightSchedule: Bool {
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        return startMinutes > endMinutes
    }

    /// Toggles a weekday in the selected days.
    func toggleDay(_ day: Weekday) {
        if scheduleDays.contains(day) {
            scheduleDays.remove(day)
        } else {
            scheduleDays.insert(day)
        }
        checkForOverlaps()
    }

    /// Checks for schedule overlaps with other profiles.
    func checkForOverlaps() {
        guard isScheduleEnabled, !scheduleDays.isEmpty else {
            scheduleConflicts = []
            return
        }

        let schedule = ScheduleConfig(
            days: Array(scheduleDays).sorted(),
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )

        // Get existing profiles with schedules
        guard let existingProfiles = try? service.fetchAll() else {
            scheduleConflicts = []
            return
        }

        let profilesWithSchedules = existingProfiles
            .filter { !$0.scheduleDays.isEmpty }
            .map { profile in
                (
                    name: profile.name,
                    id: profile.id,
                    schedule: ScheduleConfig(
                        days: profile.scheduleDays.compactMap { Weekday(dayNumber: $0) },
                        startHour: profile.scheduleStartHour,
                        startMinute: profile.scheduleStartMinute,
                        endHour: profile.scheduleEndHour,
                        endMinute: profile.scheduleEndMinute
                    )
                )
            }

        scheduleConflicts = overlapDetector.detectConflicts(
            targetSchedule: schedule,
            targetProfileName: name.isEmpty ? "This profile" : name,
            existingProfiles: profilesWithSchedules,
            excludeProfileId: editingProfileId
        )
    }

    // MARK: - Actions

    /// Saves the form (create or update), including schedule data.
    func save() {
        isSaving = true
        errorMessage = nil
        scheduleErrorMessage = nil

        do {
            if let editId = editingProfileId {
                // Update profile name/icon/color
                try service.updateProfile(
                    id: editId,
                    name: name,
                    iconName: iconName,
                    colorHex: colorHex
                )

                // Update schedule
                if isScheduleEnabled && !scheduleDays.isEmpty {
                    try service.updateSchedule(
                        id: editId,
                        scheduleDays: scheduleDays.map(\.rawValue),
                        startHour: startHour,
                        startMinute: startMinute,
                        endHour: endHour,
                        endMinute: endMinute
                    )
                } else {
                    // Clear schedule
                    try service.updateSchedule(
                        id: editId,
                        scheduleDays: [],
                        startHour: 9,
                        startMinute: 0,
                        endHour: 17,
                        endMinute: 0
                    )
                }
            } else {
                // Create profile first
                let profile = try service.createProfile(
                    name: name,
                    iconName: iconName,
                    colorHex: colorHex
                )

                // Then set schedule if enabled
                if isScheduleEnabled && !scheduleDays.isEmpty {
                    try service.updateSchedule(
                        id: profile.id,
                        scheduleDays: scheduleDays.map(\.rawValue),
                        startHour: startHour,
                        startMinute: startMinute,
                        endHour: endHour,
                        endMinute: endMinute
                    )
                }
            }
            didSave = true
        } catch let error as ScheduleManagerError {
            scheduleErrorMessage = error.localizedDescription
        } catch let error as ScheduleValidationError {
            scheduleErrorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
