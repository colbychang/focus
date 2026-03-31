import Foundation

// MARK: - Weekday

/// Represents a day of the week for schedule configuration.
/// Raw values match `DateComponents.weekday` (1 = Sunday, ..., 7 = Saturday).
public enum Weekday: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public var id: Int { rawValue }

    /// Short display name (e.g., "Mon", "Tue").
    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    /// Full display name (e.g., "Monday", "Tuesday").
    public var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// All weekdays ordered Monday through Sunday (UI display order).
    public static var orderedForDisplay: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Initialize from an integer value (1-7). Returns nil for invalid values.
    public init?(dayNumber: Int) {
        self.init(rawValue: dayNumber)
    }
}
