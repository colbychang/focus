import Foundation

// MARK: - ShieldConfigurationProvider

/// Provides branded shield configuration data for the ShieldConfigurationExtension.
/// This lives in FocusCore so the extension can import it directly.
///
/// The provider returns display metadata (title, subtitle, button labels, colors)
/// without referencing ManagedSettings types directly, allowing unit testing
/// without the Screen Time framework.
public struct ShieldConfigurationProvider: Sendable {

    // MARK: - Configuration Data

    /// The title displayed on the shield overlay.
    public static let title = "App Blocked by Focault"

    /// The subtitle displayed below the title.
    public static let subtitle = "Stay focused! This app is blocked."

    /// The label for the primary action button.
    public static let primaryButtonLabel = "Request Access"

    /// The label for the secondary action button.
    public static let secondaryButtonLabel = "Close"

    // MARK: - Brand Colors (RGB components, 0.0–1.0)

    /// The primary brand color used for the shield background.
    /// A deep focus blue.
    public static let brandColorRed: Double = 0.2
    public static let brandColorGreen: Double = 0.4
    public static let brandColorBlue: Double = 0.8

    /// The secondary brand color used for button accents.
    /// A lighter blue for buttons.
    public static let accentColorRed: Double = 0.3
    public static let accentColorGreen: Double = 0.5
    public static let accentColorBlue: Double = 0.9

    // MARK: - Configuration Result

    /// A struct containing all shield configuration data.
    /// Used to pass configuration to the extension in a testable way.
    public struct Configuration: Equatable, Sendable {
        public let title: String
        public let subtitle: String
        public let primaryButtonLabel: String
        public let secondaryButtonLabel: String
        public let backgroundColorRed: Double
        public let backgroundColorGreen: Double
        public let backgroundColorBlue: Double

        public init(
            title: String,
            subtitle: String,
            primaryButtonLabel: String,
            secondaryButtonLabel: String,
            backgroundColorRed: Double,
            backgroundColorGreen: Double,
            backgroundColorBlue: Double
        ) {
            self.title = title
            self.subtitle = subtitle
            self.primaryButtonLabel = primaryButtonLabel
            self.secondaryButtonLabel = secondaryButtonLabel
            self.backgroundColorRed = backgroundColorRed
            self.backgroundColorGreen = backgroundColorGreen
            self.backgroundColorBlue = backgroundColorBlue
        }
    }

    // MARK: - Public API

    /// Returns the branded shield configuration.
    ///
    /// - Returns: A `Configuration` struct with all branding metadata.
    public static func configuration() -> Configuration {
        Configuration(
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: primaryButtonLabel,
            secondaryButtonLabel: secondaryButtonLabel,
            backgroundColorRed: brandColorRed,
            backgroundColorGreen: brandColorGreen,
            backgroundColorBlue: brandColorBlue
        )
    }
}
