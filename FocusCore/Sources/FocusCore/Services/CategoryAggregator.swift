import Foundation

// MARK: - CategoryUsage

/// Usage data aggregated under a single category.
public struct CategoryUsage: Equatable, Sendable {
    /// The category name (e.g., a user-defined focus mode group name, or "Uncategorized").
    public let categoryName: String
    /// Total usage duration in seconds for this category.
    public let totalDuration: TimeInterval
    /// Number of sessions attributed to this category.
    public let sessionCount: Int

    public init(categoryName: String, totalDuration: TimeInterval, sessionCount: Int) {
        self.categoryName = categoryName
        self.totalDuration = totalDuration
        self.sessionCount = sessionCount
    }
}

// MARK: - CategoryAggregationResult

/// The result of category-based usage aggregation.
public struct CategoryAggregationResult: Equatable, Sendable {
    /// Per-category usage breakdowns.
    public let categories: [CategoryUsage]
    /// The grand total of all usage (should equal sum of all category totals).
    public let grandTotal: TimeInterval

    public init(categories: [CategoryUsage], grandTotal: TimeInterval) {
        self.categories = categories
        self.grandTotal = grandTotal
    }

    /// Returns the usage for the "Uncategorized" group, if any.
    public var uncategorized: CategoryUsage? {
        categories.first { $0.categoryName == CategoryAggregator.uncategorizedName }
    }
}

// MARK: - CategoryAggregator

/// Aggregates usage data under user-defined focus mode groups.
///
/// Rules:
/// - Sessions with a focusMode relationship are assigned to their focus mode's name.
/// - Sessions without a focusMode are placed in "Uncategorized".
/// - All category totals must sum to the grand total.
/// - Only completed sessions are included in the aggregation.
public struct CategoryAggregator: Sendable {

    /// The name used for sessions not belonging to any user-defined group.
    public static let uncategorizedName = "Uncategorized"

    // MARK: - Initialization

    public init() {}

    // MARK: - Aggregate

    /// Aggregates sessions by their associated focus mode group.
    ///
    /// - Parameter sessions: All deep focus sessions (any status). Only `.completed` are considered.
    /// - Returns: A `CategoryAggregationResult` with per-category breakdowns and the grand total.
    public func aggregate(sessions: [DeepFocusSession]) -> CategoryAggregationResult {
        let completedSessions = sessions.filter { $0.status == .completed }

        // Group by focus mode name (or "Uncategorized")
        var groupedDurations: [String: TimeInterval] = [:]
        var groupedCounts: [String: Int] = [:]

        for session in completedSessions {
            let categoryName: String
            if let focusMode = session.focusMode {
                categoryName = focusMode.name
            } else {
                categoryName = Self.uncategorizedName
            }

            groupedDurations[categoryName, default: 0] += session.configuredDuration
            groupedCounts[categoryName, default: 0] += 1
        }

        // Build result
        let grandTotal = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }

        let categories = groupedDurations.keys.sorted().map { name in
            CategoryUsage(
                categoryName: name,
                totalDuration: groupedDurations[name] ?? 0,
                sessionCount: groupedCounts[name] ?? 0
            )
        }

        return CategoryAggregationResult(categories: categories, grandTotal: grandTotal)
    }
}
