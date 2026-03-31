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

    // MARK: - Edit Mode

    /// The ID of the profile being edited (nil for create mode).
    let editingProfileId: UUID?

    /// Whether this form is in edit mode.
    var isEditing: Bool { editingProfileId != nil }

    // MARK: - Dependencies

    private let service: FocusModeService

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

    // MARK: - Actions

    /// Saves the form (create or update).
    func save() {
        isSaving = true
        errorMessage = nil

        do {
            if let editId = editingProfileId {
                try service.updateProfile(
                    id: editId,
                    name: name,
                    iconName: iconName,
                    colorHex: colorHex
                )
            } else {
                try service.createProfile(
                    name: name,
                    iconName: iconName,
                    colorHex: colorHex
                )
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
