import Foundation
import SwiftData

// MARK: - FocusModeServiceError

/// Errors that can occur during focus mode operations.
public enum FocusModeServiceError: Error, LocalizedError, Equatable {
    /// The profile name is empty or contains only whitespace.
    case emptyName
    /// A profile with this name (case-insensitive) already exists.
    case duplicateName(String)
    /// The profile with the given ID was not found.
    case profileNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Profile name cannot be empty"
        case .duplicateName(let name):
            return "A profile named '\(name)' already exists"
        case .profileNotFound(let id):
            return "Profile with ID \(id) not found"
        }
    }
}

// MARK: - FocusModeService

/// Service for managing FocusMode profiles (CRUD operations with validation).
/// Operates on a SwiftData ModelContext and interacts with shield/monitoring services
/// for cleanup on deletion.
@MainActor
public final class FocusModeService {

    // MARK: - Constants

    /// Key prefix for profile name storage in App Group UserDefaults.
    /// Full key format: "profile_name_<uuid>".
    public static let profileNameKeyPrefix = "profile_name_"

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let shieldService: ShieldServiceProtocol
    private let monitoringService: MonitoringServiceProtocol

    /// App Group UserDefaults for mirroring profile names to extensions.
    private let profileNameDefaults: UserDefaults?

    // MARK: - Initialization

    /// Creates a FocusModeService with the given dependencies.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData model context for persistence.
    ///   - shieldService: The shield service for clearing shields on profile deletion.
    ///   - monitoringService: The monitoring service for stopping monitors on profile deletion.
    ///   - profileNameDefaults: App Group UserDefaults for mirroring profile names.
    ///     Defaults to App Group suite. Pass a custom instance for testing.
    public init(
        modelContext: ModelContext,
        shieldService: ShieldServiceProtocol,
        monitoringService: MonitoringServiceProtocol,
        profileNameDefaults: UserDefaults? = UserDefaults(suiteName: FocusCore.appGroupIdentifier)
    ) {
        self.modelContext = modelContext
        self.shieldService = shieldService
        self.monitoringService = monitoringService
        self.profileNameDefaults = profileNameDefaults
    }

    // MARK: - Create

    /// Creates a new focus mode profile with validation.
    ///
    /// - Parameters:
    ///   - name: The display name for the profile. Must not be empty or whitespace-only.
    ///   - iconName: The SF Symbol name for the icon. Defaults to "moon.fill".
    ///   - colorHex: The hex color string. Defaults to "#4A90D9".
    /// - Returns: The newly created FocusMode.
    /// - Throws: `FocusModeServiceError.emptyName` if name is empty/whitespace,
    ///           `FocusModeServiceError.duplicateName` if a profile with this name exists.
    @discardableResult
    public func createProfile(
        name: String,
        iconName: String = "moon.fill",
        colorHex: String = "#4A90D9"
    ) throws -> FocusMode {
        // Validate non-empty name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FocusModeServiceError.emptyName
        }

        // Validate no duplicate (case-insensitive)
        let existingProfiles = try fetchAll()
        let lowercaseName = trimmedName.lowercased()
        if existingProfiles.contains(where: { $0.name.lowercased() == lowercaseName }) {
            throw FocusModeServiceError.duplicateName(trimmedName)
        }

        // Create and insert the new profile
        let profile = FocusMode(
            name: trimmedName,
            iconName: iconName,
            colorHex: colorHex
        )
        modelContext.insert(profile)
        try modelContext.save()

        // Mirror profile name to App Group UserDefaults for extension access
        mirrorProfileName(profile)

        return profile
    }

    // MARK: - Read

    /// Fetches all focus mode profiles, sorted by creation date (oldest first).
    ///
    /// - Returns: An array of all FocusMode profiles.
    public func fetchAll() throws -> [FocusMode] {
        let descriptor = FetchDescriptor<FocusMode>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches all currently active focus mode profiles.
    ///
    /// - Returns: An array of active FocusMode profiles.
    public func fetchActive() throws -> [FocusMode] {
        let descriptor = FetchDescriptor<FocusMode>(
            predicate: #Predicate<FocusMode> { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Update

    /// Updates an existing focus mode profile with validation.
    ///
    /// - Parameters:
    ///   - id: The UUID of the profile to update.
    ///   - name: The new display name. Must not be empty or whitespace-only.
    ///   - iconName: The new SF Symbol name for the icon.
    ///   - colorHex: The new hex color string.
    /// - Throws: `FocusModeServiceError.profileNotFound` if the profile doesn't exist,
    ///           `FocusModeServiceError.emptyName` if name is empty/whitespace,
    ///           `FocusModeServiceError.duplicateName` if another profile has this name.
    public func updateProfile(
        id: UUID,
        name: String,
        iconName: String,
        colorHex: String
    ) throws {
        // Validate non-empty name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FocusModeServiceError.emptyName
        }

        // Find the profile
        guard let profile = try fetchProfile(by: id) else {
            throw FocusModeServiceError.profileNotFound(id)
        }

        // Check for duplicate name (excluding this profile)
        let existingProfiles = try fetchAll()
        let lowercaseName = trimmedName.lowercased()
        if existingProfiles.contains(where: { $0.id != id && $0.name.lowercased() == lowercaseName }) {
            throw FocusModeServiceError.duplicateName(trimmedName)
        }

        // Update properties
        profile.name = trimmedName
        profile.iconName = iconName
        profile.colorHex = colorHex
        try modelContext.save()

        // Mirror updated name to App Group UserDefaults for extension access
        mirrorProfileName(profile)
    }

    /// Updates a focus mode profile's schedule and re-registers monitoring.
    ///
    /// - Parameters:
    ///   - id: The UUID of the profile to update.
    ///   - scheduleDays: Array of weekday integers (1=Sunday, 7=Saturday).
    ///   - startHour: Schedule start hour (0-23).
    ///   - startMinute: Schedule start minute (0-59).
    ///   - endHour: Schedule end hour (0-23).
    ///   - endMinute: Schedule end minute (0-59).
    /// - Throws: `FocusModeServiceError.profileNotFound`, `ScheduleValidationError`,
    ///           or `ScheduleManagerError.scheduleLimitReached`.
    public func updateSchedule(
        id: UUID,
        scheduleDays: [Int],
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) throws {
        guard let profile = try fetchProfile(by: id) else {
            throw FocusModeServiceError.profileNotFound(id)
        }

        // Update schedule properties on the profile
        profile.scheduleDays = scheduleDays
        profile.scheduleStartHour = startHour
        profile.scheduleStartMinute = startMinute
        profile.scheduleEndHour = endHour
        profile.scheduleEndMinute = endMinute
        try modelContext.save()

        // Re-register monitoring if schedule has days
        let monitorName = activityName(for: profile)
        if !scheduleDays.isEmpty {
            let schedule = ScheduleConfig(
                days: scheduleDays.compactMap { Weekday(dayNumber: $0) },
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                repeats: true
            )

            // Stop old monitoring first
            monitoringService.stopMonitoring(activityNames: [monitorName])

            // Start new monitoring
            try monitoringService.startMonitoring(activityName: monitorName, schedule: schedule)
        } else {
            // No days selected — stop monitoring
            monitoringService.stopMonitoring(activityNames: [monitorName])
        }
    }

    // MARK: - Delete

    /// Deletes a focus mode profile and cleans up associated shields and monitoring.
    ///
    /// - Parameter id: The UUID of the profile to delete.
    /// - Throws: `FocusModeServiceError.profileNotFound` if the profile doesn't exist.
    public func deleteProfile(id: UUID) throws {
        guard let profile = try fetchProfile(by: id) else {
            throw FocusModeServiceError.profileNotFound(id)
        }

        // Clear associated shield store (named by profile UUID)
        let storeName = profile.id.uuidString
        shieldService.clearShields(storeName: storeName)

        // Stop associated monitoring (using consistent focus_<uuid> naming)
        let monitorName = activityName(for: profile)
        monitoringService.stopMonitoring(activityNames: [monitorName])

        // Remove mirrored profile name from App Group UserDefaults
        removeProfileName(profile)

        // Delete from SwiftData
        modelContext.delete(profile)
        try modelContext.save()
    }

    // MARK: - Private Helpers

    /// Generates the activity name for a focus mode profile.
    /// Uses the same `focus_<uuid>` format as `ScheduleManager.activityName(for:)`
    /// for consistency across all code paths.
    private func activityName(for profile: FocusMode) -> String {
        "focus_\(profile.id.uuidString)"
    }

    /// Fetches a single profile by its UUID.
    private func fetchProfile(by id: UUID) throws -> FocusMode? {
        let descriptor = FetchDescriptor<FocusMode>(
            predicate: #Predicate<FocusMode> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Mirrors a profile's display name to App Group UserDefaults
    /// so extensions can look up human-readable names without SwiftData access.
    private func mirrorProfileName(_ profile: FocusMode) {
        let key = Self.profileNameKeyPrefix + profile.id.uuidString
        profileNameDefaults?.set(profile.name, forKey: key)
    }

    /// Removes a profile's mirrored name from App Group UserDefaults on deletion.
    private func removeProfileName(_ profile: FocusMode) {
        let key = Self.profileNameKeyPrefix + profile.id.uuidString
        profileNameDefaults?.removeObject(forKey: key)
    }
}
