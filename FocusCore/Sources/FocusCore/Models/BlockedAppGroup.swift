import Foundation
import SwiftData

// MARK: - BlockedAppGroup

extension AppSchemaV2 {

    /// A named group of blocked app tokens for category-based management
    /// and analytics aggregation.
    @Model
    public final class BlockedAppGroup {
        /// Unique identifier for this group.
        public var id: UUID

        /// Display name of the blocked app group.
        public var name: String

        /// Serialized application tokens for apps in this group.
        public var serializedAppTokens: Data?

        public init(
            id: UUID = UUID(),
            name: String,
            serializedAppTokens: Data? = nil
        ) {
            self.id = id
            self.name = name
            self.serializedAppTokens = serializedAppTokens
        }
    }
}

/// Public typealias for the current schema version's BlockedAppGroup.
public typealias BlockedAppGroup = AppSchemaV2.BlockedAppGroup
