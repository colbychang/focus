import Foundation
import SwiftData

// MARK: - AppSchemaV1

/// The first version of the app's data schema (original).
/// Contains FocusMode WITHOUT isManuallyActivated.
public enum AppSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            AppSchemaV1.FocusMode.self
        ]
    }
}

// MARK: - AppSchemaV2

/// The second version of the app's data schema.
/// Adds `isManuallyActivated` to FocusMode with default value of `false`.
/// All current models are defined in this schema version.
public enum AppSchemaV2: VersionedSchema {
    public static var versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            AppSchemaV2.FocusMode.self,
            AppSchemaV2.DeepFocusSession.self,
            AppSchemaV2.ScreenTimeEntry.self,
            AppSchemaV2.BlockedAppGroup.self
        ]
    }
}

// MARK: - SchemaMigrationPlan

/// Migration plan for the app's data schema.
/// V1 → V2: Adds isManuallyActivated to FocusMode (lightweight migration).
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Lightweight migration from V1 to V2.
    /// Adds isManuallyActivated (Bool with default false) to FocusMode.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )
}
