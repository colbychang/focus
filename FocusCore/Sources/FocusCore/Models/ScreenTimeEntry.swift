import Foundation
import SwiftData

// MARK: - ScreenTimeEntry

extension AppSchemaV2 {

    /// A record of screen time usage for a specific app or category.
    @Model
    public final class ScreenTimeEntry {
        /// Unique identifier for this entry.
        public var id: UUID

        /// The date this entry is attributed to.
        public var date: Date

        /// The bundle identifier or opaque app identifier string.
        public var appIdentifier: String?

        /// The category name for this usage entry.
        public var categoryName: String?

        /// Duration of usage in seconds.
        public var duration: TimeInterval

        /// Optional session ID linking this entry to a specific deep focus session.
        public var sessionID: UUID?

        public init(
            id: UUID = UUID(),
            date: Date = Date(),
            appIdentifier: String? = nil,
            categoryName: String? = nil,
            duration: TimeInterval = 0,
            sessionID: UUID? = nil
        ) {
            self.id = id
            self.date = date
            self.appIdentifier = appIdentifier
            self.categoryName = categoryName
            self.duration = duration
            self.sessionID = sessionID
        }
    }
}

/// Public typealias for the current schema version's ScreenTimeEntry.
public typealias ScreenTimeEntry = AppSchemaV2.ScreenTimeEntry
