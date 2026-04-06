import Foundation

// MARK: - ModeTypeUsage

/// Focus time usage for a single mode type.
public struct ModeTypeUsage: Equatable, Sendable {
    /// The mode type name (e.g., "Work", "Study", "Deep Focus").
    public let modeType: String
    /// Total focus time for this mode type, in seconds.
    public let totalDuration: TimeInterval
    /// Number of completed sessions for this mode type.
    public let sessionCount: Int

    public init(modeType: String, totalDuration: TimeInterval, sessionCount: Int) {
        self.modeType = modeType
        self.totalDuration = totalDuration
        self.sessionCount = sessionCount
    }
}

// MARK: - ModeTypeBreakdownResult

/// The result of focus time breakdown by mode type.
public struct ModeTypeBreakdownResult: Equatable, Sendable {
    /// Per-type usage breakdowns.
    public let modeTypes: [ModeTypeUsage]
    /// The grand total of all focus time (should equal sum of all per-type totals).
    public let grandTotal: TimeInterval

    public init(modeTypes: [ModeTypeUsage], grandTotal: TimeInterval) {
        self.modeTypes = modeTypes
        self.grandTotal = grandTotal
    }

    /// Returns the usage for a specific mode type by name.
    public func usage(for modeType: String) -> ModeTypeUsage? {
        modeTypes.first { $0.modeType == modeType }
    }
}

// MARK: - ModeTypeBreakdown

/// Breaks down total focus time by mode type (Work, Study, etc.).
///
/// Rules:
/// - Sessions linked to a FocusMode use that mode's name as the type.
/// - Sessions without a FocusMode are classified as "Deep Focus".
/// - Only completed sessions are included.
/// - Per-type totals must sum to the grand total.
/// - Custom mode types (user-created focus mode names) are included.
/// - Modes with zero sessions are NOT included in the result
///   (they have no session data to report).
public struct ModeTypeBreakdown: Sendable {

    /// The default mode type label for sessions without a focus mode association.
    public static let deepFocusLabel = "Deep Focus"

    // MARK: - Initialization

    public init() {}

    // MARK: - Compute Breakdown

    /// Computes the focus time breakdown by mode type.
    ///
    /// - Parameter sessions: All deep focus sessions (any status). Only `.completed` are considered.
    /// - Returns: A `ModeTypeBreakdownResult` with per-type breakdowns and the grand total.
    public func compute(sessions: [DeepFocusSession]) -> ModeTypeBreakdownResult {
        let completedSessions = sessions.filter { $0.status == .completed }

        // Group by mode type
        var groupedDurations: [String: TimeInterval] = [:]
        var groupedCounts: [String: Int] = [:]

        for session in completedSessions {
            let modeType: String
            if let focusMode = session.focusMode {
                modeType = focusMode.name
            } else {
                modeType = Self.deepFocusLabel
            }

            groupedDurations[modeType, default: 0] += session.configuredDuration
            groupedCounts[modeType, default: 0] += 1
        }

        // Build result
        let grandTotal = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }

        let modeTypes = groupedDurations.keys.sorted().map { name in
            ModeTypeUsage(
                modeType: name,
                totalDuration: groupedDurations[name] ?? 0,
                sessionCount: groupedCounts[name] ?? 0
            )
        }

        return ModeTypeBreakdownResult(modeTypes: modeTypes, grandTotal: grandTotal)
    }

    /// Computes the breakdown including all known mode types, even those with zero sessions.
    ///
    /// - Parameters:
    ///   - sessions: All deep focus sessions (any status). Only `.completed` are considered.
    ///   - allModeNames: All known focus mode names to include (even if they have 0 sessions).
    /// - Returns: A `ModeTypeBreakdownResult` with all mode types represented.
    public func computeWithAllModes(
        sessions: [DeepFocusSession],
        allModeNames: [String]
    ) -> ModeTypeBreakdownResult {
        let completedSessions = sessions.filter { $0.status == .completed }

        // Group by mode type
        var groupedDurations: [String: TimeInterval] = [:]
        var groupedCounts: [String: Int] = [:]

        // Initialize all known modes with 0
        for name in allModeNames {
            groupedDurations[name] = 0
            groupedCounts[name] = 0
        }
        // Also initialize Deep Focus
        groupedDurations[Self.deepFocusLabel] = 0
        groupedCounts[Self.deepFocusLabel] = 0

        for session in completedSessions {
            let modeType: String
            if let focusMode = session.focusMode {
                modeType = focusMode.name
            } else {
                modeType = Self.deepFocusLabel
            }

            groupedDurations[modeType, default: 0] += session.configuredDuration
            groupedCounts[modeType, default: 0] += 1
        }

        // Build result
        let grandTotal = completedSessions.reduce(0.0) { $0 + $1.configuredDuration }

        let modeTypes = groupedDurations.keys.sorted().map { name in
            ModeTypeUsage(
                modeType: name,
                totalDuration: groupedDurations[name] ?? 0,
                sessionCount: groupedCounts[name] ?? 0
            )
        }

        return ModeTypeBreakdownResult(modeTypes: modeTypes, grandTotal: grandTotal)
    }
}
