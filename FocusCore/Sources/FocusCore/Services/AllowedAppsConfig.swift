import Foundation

// MARK: - AllowedApp

/// Represents a single allowed app with its serialized token and display metadata.
/// Since Screen Time tokens are opaque, the display name and category assignment
/// are stored alongside the serialized token data.
public struct AllowedApp: Codable, Equatable, Hashable, Sendable {
    /// The serialized opaque token identifying this app.
    public let tokenData: Data
    /// A display name for the app (user-provided or inferred).
    public let displayName: String
    /// The category this app belongs to.
    public let category: AppCategory

    public init(tokenData: Data, displayName: String, category: AppCategory = .other) {
        self.tokenData = tokenData
        self.displayName = displayName
        self.category = category
    }
}

// MARK: - AppCategory

/// Categories for grouping allowed apps in the launcher view.
public enum AppCategory: String, Codable, CaseIterable, Sendable {
    case communication = "Communication"
    case work = "Work"
    case music = "Music"
    case other = "Other"

    /// Display name for the category header.
    public var displayName: String {
        rawValue
    }

    /// SF Symbol icon for the category.
    public var iconName: String {
        switch self {
        case .communication: return "message.fill"
        case .work: return "briefcase.fill"
        case .music: return "music.note"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - AllowedAppsConfig

/// Configuration for allowed apps during a deep focus session.
/// Manages the selection of apps that remain accessible during blocking.
/// Serializable for persistence in SwiftData via DeepFocusSession.serializedAllowedTokens.
public struct AllowedAppsConfig: Codable, Equatable, Sendable {
    /// The list of allowed apps with their metadata.
    public private(set) var apps: [AllowedApp]

    /// Creates an empty configuration.
    public init() {
        self.apps = []
    }

    /// Creates a configuration with the given apps.
    ///
    /// - Parameter apps: The allowed apps.
    public init(apps: [AllowedApp]) {
        self.apps = apps
    }

    /// Whether the configuration has any apps.
    public var isEmpty: Bool {
        apps.isEmpty
    }

    /// The number of allowed apps.
    public var count: Int {
        apps.count
    }

    /// Adds an app to the allowed list.
    ///
    /// - Parameter app: The app to add.
    public mutating func addApp(_ app: AllowedApp) {
        // Prevent duplicates based on token data
        guard !apps.contains(where: { $0.tokenData == app.tokenData }) else { return }
        apps.append(app)
    }

    /// Removes an app from the allowed list by its token data.
    ///
    /// - Parameter tokenData: The token data of the app to remove.
    public mutating func removeApp(withTokenData tokenData: Data) {
        apps.removeAll { $0.tokenData == tokenData }
    }

    /// Returns all token data for allowed apps.
    public var allTokenData: Set<Data> {
        Set(apps.map(\.tokenData))
    }

    // MARK: - Serialization

    /// Serializes this configuration to Data for SwiftData persistence.
    ///
    /// - Returns: Encoded data, or nil if encoding fails.
    public func serialize() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Deserializes configuration from Data.
    ///
    /// - Parameter data: The encoded data.
    /// - Returns: The decoded configuration, or nil if decoding fails.
    public static func deserialize(from data: Data) -> AllowedAppsConfig? {
        try? JSONDecoder().decode(AllowedAppsConfig.self, from: data)
    }
}
