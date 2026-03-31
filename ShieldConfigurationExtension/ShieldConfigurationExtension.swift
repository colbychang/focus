import ManagedSettingsUI
import ManagedSettings
import UIKit
import FocusCore

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    /// Returns the branded shield configuration for a blocked application.
    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        brandedConfiguration()
    }

    /// Returns the branded shield configuration for a blocked web domain.
    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        brandedConfiguration()
    }

    // MARK: - Private

    /// Builds a branded `ShieldConfiguration` using `ShieldConfigurationProvider` from FocusCore.
    private func brandedConfiguration() -> ShieldConfiguration {
        let config = ShieldConfigurationProvider.configuration()

        let backgroundColor = UIColor(
            red: config.backgroundColorRed,
            green: config.backgroundColorGreen,
            blue: config.backgroundColorBlue,
            alpha: 1.0
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: backgroundColor,
            icon: nil,
            title: ShieldConfiguration.Label(
                text: config.title,
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: config.subtitle,
                color: UIColor.white.withAlphaComponent(0.8)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: config.primaryButtonLabel,
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(
                red: ShieldConfigurationProvider.accentColorRed,
                green: ShieldConfigurationProvider.accentColorGreen,
                blue: ShieldConfigurationProvider.accentColorBlue,
                alpha: 1.0
            ),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: config.secondaryButtonLabel,
                color: UIColor.white.withAlphaComponent(0.7)
            )
        )
    }
}
