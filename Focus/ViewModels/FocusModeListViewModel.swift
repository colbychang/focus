import Foundation
import SwiftData
import FocusCore

// MARK: - FocusModeListViewModel

/// ViewModel for the focus mode profile list.
/// Manages fetching, deleting, activating, and deactivating focus mode profiles.
@MainActor
@Observable
final class FocusModeListViewModel {

    // MARK: - State

    /// All focus mode profiles, sorted by creation date.
    private(set) var profiles: [FocusMode] = []

    /// Whether the list is currently loading.
    private(set) var isLoading: Bool = false

    /// Error message to display if an operation fails.
    var errorMessage: String?

    /// Whether to show the delete confirmation alert.
    var showDeleteConfirmation: Bool = false

    /// The profile pending deletion (awaiting confirmation).
    var profileToDelete: FocusMode?

    // MARK: - Dependencies

    private let service: FocusModeService
    private let activationService: FocusModeActivationService

    // MARK: - Initialization

    /// Creates a FocusModeListViewModel with the given services.
    ///
    /// - Parameters:
    ///   - service: The focus mode service for CRUD operations.
    ///   - activationService: The activation service for activating/deactivating profiles.
    init(service: FocusModeService, activationService: FocusModeActivationService) {
        self.service = service
        self.activationService = activationService
    }

    // MARK: - Actions

    /// Loads all focus mode profiles from the data store.
    func loadProfiles() {
        isLoading = true
        do {
            profiles = try service.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Toggles the activation state of a focus mode profile.
    ///
    /// - Parameter profile: The profile to toggle.
    func toggleActivation(profile: FocusMode) {
        if profile.isActive {
            activationService.deactivate(profile: profile)
        } else {
            activationService.activate(profile: profile)
        }
        loadProfiles()
    }

    /// Initiates the delete flow for a profile (shows confirmation).
    ///
    /// - Parameter profile: The profile to delete.
    func requestDelete(profile: FocusMode) {
        profileToDelete = profile
        showDeleteConfirmation = true
    }

    /// Confirms deletion of the pending profile.
    func confirmDelete() {
        guard let profile = profileToDelete else { return }
        do {
            try service.deleteProfile(id: profile.id)
            loadProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
        profileToDelete = nil
        showDeleteConfirmation = false
    }

    /// Cancels the pending deletion.
    func cancelDelete() {
        profileToDelete = nil
        showDeleteConfirmation = false
    }

    /// Whether the list is empty (no profiles exist).
    var isEmpty: Bool {
        profiles.isEmpty
    }
}
