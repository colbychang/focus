import Foundation
import SwiftData

// MARK: - SessionStatus

/// The status of a deep focus session.
public enum SessionStatus: String, Codable, CaseIterable {
    case idle
    case active
    case onBreak
    case bypassing
    case completed
    case abandoned
}

// MARK: - DeepFocusSession

extension AppSchemaV2 {

    /// A deep focus session record tracking start time, duration, status,
    /// and usage metrics like bypass/break counts.
    @Model
    public final class DeepFocusSession {
        /// Unique identifier for this session.
        public var id: UUID

        /// When this session started.
        public var startTime: Date

        /// The total duration configured for this session, in seconds.
        public var configuredDuration: TimeInterval

        /// Remaining seconds in the session.
        public var remainingSeconds: TimeInterval

        /// Current status of the session.
        public var status: SessionStatus

        /// Number of times the user bypassed blocking during this session.
        public var bypassCount: Int

        /// Number of breaks taken during this session.
        public var breakCount: Int

        /// Total duration of all breaks taken, in seconds.
        public var totalBreakDuration: TimeInterval

        /// Serialized tokens for apps allowed during the session.
        public var serializedAllowedTokens: Data?

        /// Optional relationship to the focus mode this session is associated with.
        /// Uses `.nullify` delete rule — if the focus mode is deleted,
        /// this reference becomes nil but the session persists.
        public var focusMode: FocusMode?

        public init(
            id: UUID = UUID(),
            startTime: Date = Date(),
            configuredDuration: TimeInterval = 1800,
            remainingSeconds: TimeInterval = 1800,
            status: SessionStatus = .idle,
            bypassCount: Int = 0,
            breakCount: Int = 0,
            totalBreakDuration: TimeInterval = 0,
            serializedAllowedTokens: Data? = nil,
            focusMode: FocusMode? = nil
        ) {
            self.id = id
            self.startTime = startTime
            self.configuredDuration = configuredDuration
            self.remainingSeconds = remainingSeconds
            self.status = status
            self.bypassCount = bypassCount
            self.breakCount = breakCount
            self.totalBreakDuration = totalBreakDuration
            self.serializedAllowedTokens = serializedAllowedTokens
            self.focusMode = focusMode
        }
    }
}

/// Public typealias for the current schema version's DeepFocusSession.
public typealias DeepFocusSession = AppSchemaV2.DeepFocusSession
