import Foundation
import SwiftData

// MARK: - SessionRecord

/// A lightweight record of a focus session boundary written by the DeviceActivityMonitor extension.
/// Stored in App Group UserDefaults for later reconciliation into SwiftData.
public struct SessionRecord: Codable, Equatable, Sendable {
    /// Unique ID for this session record.
    public let id: UUID
    /// The profile UUID this session belongs to.
    public let profileId: UUID
    /// The profile name at the time of recording.
    public let profileName: String
    /// When the session started.
    public let startTimestamp: TimeInterval
    /// When the session ended (nil if still active).
    public var endTimestamp: TimeInterval?

    public init(
        id: UUID = UUID(),
        profileId: UUID,
        profileName: String,
        startTimestamp: TimeInterval,
        endTimestamp: TimeInterval? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.profileName = profileName
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
    }

    /// Duration in seconds, or nil if the session is still active.
    public var duration: TimeInterval? {
        guard let end = endTimestamp else { return nil }
        return max(0, end - startTimestamp)
    }
}

// MARK: - FocusSessionRecorder

/// Records focus mode session boundaries via App Group UserDefaults.
///
/// When `DeviceActivityMonitor.intervalDidStart` fires, the extension calls
/// `recordSessionStart(profileId:profileName:)` to write the start timestamp.
///
/// When `intervalDidEnd` fires, the extension calls `recordSessionEnd(profileId:)`
/// to write the end timestamp.
///
/// On main app launch, `reconcileSessions(modelContext:)` reads all completed
/// session records from UserDefaults and creates corresponding `ScreenTimeEntry`
/// records in SwiftData, then clears the processed records.
public final class FocusSessionRecorder: @unchecked Sendable {

    // MARK: - Properties

    private let defaults: UserDefaults
    private let dateProvider: () -> Date

    // MARK: - Keys

    private static let pendingRecordsKey = SharedStateKey.pendingSessionRecords.rawValue
    private static let activeStartsKey = SharedStateKey.activeSessionStarts.rawValue

    // MARK: - Initialization

    /// Creates a session recorder with the given UserDefaults instance.
    ///
    /// - Parameters:
    ///   - defaults: The App Group UserDefaults instance.
    ///   - dateProvider: A closure providing the current date. Defaults to `Date()`.
    public init(
        defaults: UserDefaults,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.dateProvider = dateProvider
    }

    /// Creates a session recorder with the standard App Group suite.
    ///
    /// - Parameter dateProvider: A closure providing the current date. Defaults to `Date()`.
    public convenience init(
        suiteName: String? = nil,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        let suite = suiteName ?? FocusCore.appGroupIdentifier
        let ud = UserDefaults(suiteName: suite) ?? UserDefaults.standard
        self.init(defaults: ud, dateProvider: dateProvider)
    }

    // MARK: - Record Session Start

    /// Records the start of a focus session for a profile.
    /// Called by DeviceActivityMonitor when `intervalDidStart` fires.
    ///
    /// - Parameters:
    ///   - profileId: The UUID of the focus mode profile.
    ///   - profileName: The display name of the profile.
    public func recordSessionStart(profileId: UUID, profileName: String) {
        let now = dateProvider().timeIntervalSince1970
        var activeStarts = loadActiveStarts()
        activeStarts[profileId.uuidString] = SessionRecord(
            profileId: profileId,
            profileName: profileName,
            startTimestamp: now
        )
        saveActiveStarts(activeStarts)
    }

    // MARK: - Record Session End

    /// Records the end of a focus session for a profile.
    /// Called by DeviceActivityMonitor when `intervalDidEnd` fires.
    /// Moves the completed session from active starts to pending records.
    ///
    /// - Parameter profileId: The UUID of the focus mode profile.
    public func recordSessionEnd(profileId: UUID) {
        let now = dateProvider().timeIntervalSince1970
        var activeStarts = loadActiveStarts()

        guard var record = activeStarts[profileId.uuidString] else {
            // No active session for this profile — create a minimal record
            // This can happen if the app was reinstalled or data was cleared
            return
        }

        // Set end timestamp and move to pending
        record.endTimestamp = now
        activeStarts.removeValue(forKey: profileId.uuidString)
        saveActiveStarts(activeStarts)

        // Add to pending records
        var pending = loadPendingRecords()
        pending.append(record)
        savePendingRecords(pending)
    }

    // MARK: - Reconciliation

    /// Reconciles pending session records from UserDefaults into SwiftData ScreenTimeEntry records.
    /// Called on main app launch.
    ///
    /// - Parameter modelContext: The SwiftData model context to create entries in.
    /// - Returns: The number of records reconciled.
    @MainActor
    @discardableResult
    public func reconcileSessions(modelContext: ModelContext) -> Int {
        let pending = loadPendingRecords()
        guard !pending.isEmpty else { return 0 }

        var reconciledCount = 0
        for record in pending {
            guard let duration = record.duration, duration > 0 else { continue }

            let entry = ScreenTimeEntry(
                id: record.id,
                date: Date(timeIntervalSince1970: record.startTimestamp),
                appIdentifier: nil,
                categoryName: "Focus Session: \(record.profileName)",
                duration: duration,
                sessionID: nil
            )
            modelContext.insert(entry)
            reconciledCount += 1
        }

        if reconciledCount > 0 {
            try? modelContext.save()
        }

        // Clear processed records
        savePendingRecords([])

        return reconciledCount
    }

    // MARK: - Query

    /// Returns the currently active session starts (sessions that have started but not ended).
    public func activeSessionStarts() -> [String: SessionRecord] {
        loadActiveStarts()
    }

    /// Returns all pending (completed but not yet reconciled) session records.
    public func pendingRecords() -> [SessionRecord] {
        loadPendingRecords()
    }

    /// Checks whether a profile has an active (started but not ended) session.
    ///
    /// - Parameter profileId: The UUID of the profile to check.
    /// - Returns: `true` if the profile has an active session.
    public func hasActiveSession(profileId: UUID) -> Bool {
        let starts = loadActiveStarts()
        return starts[profileId.uuidString] != nil
    }

    // MARK: - Persistence Helpers

    private func loadActiveStarts() -> [String: SessionRecord] {
        guard let data = defaults.data(forKey: Self.activeStartsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: SessionRecord].self, from: data)) ?? [:]
    }

    private func saveActiveStarts(_ starts: [String: SessionRecord]) {
        guard let data = try? JSONEncoder().encode(starts) else { return }
        defaults.set(data, forKey: Self.activeStartsKey)
    }

    private func loadPendingRecords() -> [SessionRecord] {
        guard let data = defaults.data(forKey: Self.pendingRecordsKey) else { return [] }
        return (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    private func savePendingRecords(_ records: [SessionRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.pendingRecordsKey)
    }
}
