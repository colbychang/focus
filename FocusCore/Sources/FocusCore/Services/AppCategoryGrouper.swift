import Foundation

// MARK: - CategoryGroup

/// A group of apps under a single category, used for display in the launcher view.
public struct CategoryGroup: Equatable, Sendable {
    /// The category for this group.
    public let category: AppCategory
    /// The apps in this category.
    public let apps: [AllowedApp]

    /// Whether this group has any apps.
    public var isEmpty: Bool {
        apps.isEmpty
    }

    public init(category: AppCategory, apps: [AllowedApp]) {
        self.category = category
        self.apps = apps
    }
}

// MARK: - AppCategoryGrouper

/// Groups allowed apps into categories for display in the launcher view.
/// Categories with no apps are excluded from the results.
/// Apps are sorted alphabetically within each category.
public enum AppCategoryGrouper {

    /// Groups the given allowed apps by their assigned category.
    /// Categories with no apps are excluded from the result.
    /// Apps within each category are sorted alphabetically by display name.
    ///
    /// - Parameter config: The allowed apps configuration.
    /// - Returns: An array of category groups with non-empty categories only,
    ///   ordered by the standard category order (Communication, Work, Music, Other).
    public static func group(config: AllowedAppsConfig) -> [CategoryGroup] {
        // Group apps by category
        var grouped: [AppCategory: [AllowedApp]] = [:]
        for app in config.apps {
            grouped[app.category, default: []].append(app)
        }

        // Sort apps alphabetically within each category
        for (category, apps) in grouped {
            grouped[category] = apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        // Return groups in standard category order, excluding empty categories
        return AppCategory.allCases.compactMap { category in
            guard let apps = grouped[category], !apps.isEmpty else { return nil }
            return CategoryGroup(category: category, apps: apps)
        }
    }

    /// Groups apps from a serialized configuration.
    ///
    /// - Parameter data: Serialized AllowedAppsConfig data.
    /// - Returns: An array of category groups, or an empty array if deserialization fails.
    public static func group(fromSerializedData data: Data?) -> [CategoryGroup] {
        guard let data,
              let config = AllowedAppsConfig.deserialize(from: data) else {
            return []
        }
        return group(config: config)
    }
}
