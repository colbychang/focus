import Foundation
import SwiftData

// MARK: - AppSchemaV1

/// The first version of the app's data schema.
/// All SwiftData models are defined within this versioned schema
/// to enable safe schema evolution in future versions.
public enum AppSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            FocusMode.self,
            DeepFocusSession.self,
            ScreenTimeEntry.self,
            BlockedAppGroup.self
        ]
    }
}

// MARK: - SchemaMigrationPlan

/// Migration plan for the app's data schema.
/// Currently contains only V1 (initial version).
/// Future versions will add migration stages here.
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
