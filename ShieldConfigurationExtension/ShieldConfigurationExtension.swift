import ManagedSettingsUI
import ManagedSettings
import FocusCore

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
