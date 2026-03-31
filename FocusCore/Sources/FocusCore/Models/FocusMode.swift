import Foundation
import SwiftData

// MARK: - FocusMode (V1 — original, without isManuallyActivated)

extension AppSchemaV1 {

    /// A focus mode profile that defines which apps to block, on what schedule,
    /// and with what visual identity (icon, color).
    /// V1 original — does NOT include `isManuallyActivated`.
    @Model
    public final class FocusMode {
        /// Unique identifier for this focus mode.
        public var id: UUID

        /// Display name of the focus mode (e.g., "Work", "Evening").
        /// Must be non-empty.
        public var name: String

        /// SF Symbol name for the focus mode icon.
        public var iconName: String

        /// Hex color string for the focus mode (e.g., "#4A90D9").
        public var colorHex: String

        /// Days of the week when this focus mode is scheduled.
        /// Represented as integers: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
        public var scheduleDays: [Int]

        /// Hour component of the schedule start time (0–23).
        public var scheduleStartHour: Int

        /// Minute component of the schedule start time (0–59).
        public var scheduleStartMinute: Int

        /// Hour component of the schedule end time (0–23).
        public var scheduleEndHour: Int

        /// Minute component of the schedule end time (0–59).
        public var scheduleEndMinute: Int

        /// Serialized application tokens for apps to block.
        public var serializedAppTokens: Data?

        /// Serialized category tokens for categories to block.
        public var serializedCategoryTokens: Data?

        /// Serialized web domain tokens for web domains to block.
        public var serializedWebDomainTokens: Data?

        /// Whether this focus mode is currently active (blocking apps).
        public var isActive: Bool

        /// When this focus mode was created.
        public var createdAt: Date

        public init(
            id: UUID = UUID(),
            name: String,
            iconName: String = "moon.fill",
            colorHex: String = "#4A90D9",
            scheduleDays: [Int] = [],
            scheduleStartHour: Int = 9,
            scheduleStartMinute: Int = 0,
            scheduleEndHour: Int = 17,
            scheduleEndMinute: Int = 0,
            serializedAppTokens: Data? = nil,
            serializedCategoryTokens: Data? = nil,
            serializedWebDomainTokens: Data? = nil,
            isActive: Bool = false,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.colorHex = colorHex
            self.scheduleDays = scheduleDays
            self.scheduleStartHour = scheduleStartHour
            self.scheduleStartMinute = scheduleStartMinute
            self.scheduleEndHour = scheduleEndHour
            self.scheduleEndMinute = scheduleEndMinute
            self.serializedAppTokens = serializedAppTokens
            self.serializedCategoryTokens = serializedCategoryTokens
            self.serializedWebDomainTokens = serializedWebDomainTokens
            self.isActive = isActive
            self.createdAt = createdAt
        }
    }
}

// MARK: - FocusMode (V2 — adds isManuallyActivated)

extension AppSchemaV2 {

    /// A focus mode profile that defines which apps to block, on what schedule,
    /// and with what visual identity (icon, color).
    /// V2 adds `isManuallyActivated` with a default value of `false`.
    @Model
    public final class FocusMode {
        /// Unique identifier for this focus mode.
        public var id: UUID

        /// Display name of the focus mode (e.g., "Work", "Evening").
        /// Must be non-empty.
        public var name: String

        /// SF Symbol name for the focus mode icon.
        public var iconName: String

        /// Hex color string for the focus mode (e.g., "#4A90D9").
        public var colorHex: String

        /// Days of the week when this focus mode is scheduled.
        /// Represented as integers: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
        public var scheduleDays: [Int]

        /// Hour component of the schedule start time (0–23).
        public var scheduleStartHour: Int

        /// Minute component of the schedule start time (0–59).
        public var scheduleStartMinute: Int

        /// Hour component of the schedule end time (0–23).
        public var scheduleEndHour: Int

        /// Minute component of the schedule end time (0–59).
        public var scheduleEndMinute: Int

        /// Serialized application tokens for apps to block.
        public var serializedAppTokens: Data?

        /// Serialized category tokens for categories to block.
        public var serializedCategoryTokens: Data?

        /// Serialized web domain tokens for web domains to block.
        public var serializedWebDomainTokens: Data?

        /// Whether this focus mode is currently active (blocking apps).
        public var isActive: Bool

        /// Whether this focus mode was manually activated (as opposed to schedule-activated).
        /// When `true`, `intervalDidEnd` should NOT deactivate this profile.
        /// Added in V2 with default value of `false`.
        public var isManuallyActivated: Bool

        /// When this focus mode was created.
        public var createdAt: Date

        /// Deep focus sessions associated with this focus mode.
        /// Uses `.nullify` delete rule — sessions persist after mode deletion
        /// with their focusMode reference set to nil.
        @Relationship(deleteRule: .nullify, inverse: \DeepFocusSession.focusMode)
        public var sessions: [DeepFocusSession]

        public init(
            id: UUID = UUID(),
            name: String,
            iconName: String = "moon.fill",
            colorHex: String = "#4A90D9",
            scheduleDays: [Int] = [],
            scheduleStartHour: Int = 9,
            scheduleStartMinute: Int = 0,
            scheduleEndHour: Int = 17,
            scheduleEndMinute: Int = 0,
            serializedAppTokens: Data? = nil,
            serializedCategoryTokens: Data? = nil,
            serializedWebDomainTokens: Data? = nil,
            isActive: Bool = false,
            isManuallyActivated: Bool = false,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.colorHex = colorHex
            self.scheduleDays = scheduleDays
            self.scheduleStartHour = scheduleStartHour
            self.scheduleStartMinute = scheduleStartMinute
            self.scheduleEndHour = scheduleEndHour
            self.scheduleEndMinute = scheduleEndMinute
            self.serializedAppTokens = serializedAppTokens
            self.serializedCategoryTokens = serializedCategoryTokens
            self.serializedWebDomainTokens = serializedWebDomainTokens
            self.isActive = isActive
            self.isManuallyActivated = isManuallyActivated
            self.createdAt = createdAt
            self.sessions = []
        }
    }
}

/// Public typealias for the current schema version's FocusMode.
public typealias FocusMode = AppSchemaV2.FocusMode
