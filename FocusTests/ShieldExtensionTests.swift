import Testing
import Foundation
@testable import FocusCore

// MARK: - Shield Configuration Provider Tests

/// Tests for `ShieldConfigurationProvider` — verifies branded UI elements.
/// Covers VAL-FOCUS-013: ShieldConfigurationExtension (via mock) returns
/// branded shield UI with custom title, subtitle, colors, and button labels.
@Suite("ShieldConfigurationProvider Tests")
struct ShieldConfigurationProviderTests {

    @Test("Configuration returns correct title")
    func configurationTitle() {
        let config = ShieldConfigurationProvider.configuration()
        #expect(config.title == "App Blocked by Focault")
    }

    @Test("Configuration returns correct subtitle")
    func configurationSubtitle() {
        let config = ShieldConfigurationProvider.configuration()
        #expect(config.subtitle == "Stay focused! This app is blocked.")
    }

    @Test("Configuration returns correct primary button label")
    func configurationPrimaryButton() {
        let config = ShieldConfigurationProvider.configuration()
        #expect(config.primaryButtonLabel == "Request Access")
    }

    @Test("Configuration returns correct secondary button label")
    func configurationSecondaryButton() {
        let config = ShieldConfigurationProvider.configuration()
        #expect(config.secondaryButtonLabel == "Close")
    }

    @Test("Configuration returns valid brand colors")
    func configurationBrandColors() {
        let config = ShieldConfigurationProvider.configuration()

        // Background color components should be in valid range
        #expect(config.backgroundColorRed >= 0.0 && config.backgroundColorRed <= 1.0)
        #expect(config.backgroundColorGreen >= 0.0 && config.backgroundColorGreen <= 1.0)
        #expect(config.backgroundColorBlue >= 0.0 && config.backgroundColorBlue <= 1.0)
    }

    @Test("Configuration brand color values match provider constants")
    func configurationBrandColorValues() {
        let config = ShieldConfigurationProvider.configuration()

        #expect(config.backgroundColorRed == ShieldConfigurationProvider.brandColorRed)
        #expect(config.backgroundColorGreen == ShieldConfigurationProvider.brandColorGreen)
        #expect(config.backgroundColorBlue == ShieldConfigurationProvider.brandColorBlue)
    }

    @Test("Static constants are accessible")
    func staticConstants() {
        // Verify all static constants are accessible
        #expect(!ShieldConfigurationProvider.title.isEmpty)
        #expect(!ShieldConfigurationProvider.subtitle.isEmpty)
        #expect(!ShieldConfigurationProvider.primaryButtonLabel.isEmpty)
        #expect(!ShieldConfigurationProvider.secondaryButtonLabel.isEmpty)
    }

    @Test("Accent color values are valid")
    func accentColors() {
        #expect(ShieldConfigurationProvider.accentColorRed >= 0.0 && ShieldConfigurationProvider.accentColorRed <= 1.0)
        #expect(ShieldConfigurationProvider.accentColorGreen >= 0.0 && ShieldConfigurationProvider.accentColorGreen <= 1.0)
        #expect(ShieldConfigurationProvider.accentColorBlue >= 0.0 && ShieldConfigurationProvider.accentColorBlue <= 1.0)
    }

    @Test("Configuration is Equatable")
    func configurationEquatable() {
        let config1 = ShieldConfigurationProvider.configuration()
        let config2 = ShieldConfigurationProvider.configuration()
        #expect(config1 == config2)
    }

    @Test("Configuration is Sendable")
    func configurationSendable() {
        let config = ShieldConfigurationProvider.configuration()
        // If this compiles, the type conforms to Sendable
        let _: any Sendable = config
        #expect(config.title == "App Blocked by Focault")
    }
}

// MARK: - Shield Action Handler Tests

/// Tests for `ShieldActionHandler` — verifies both button responses and UserDefaults side effects.
/// Covers VAL-FOCUS-013: ShieldActionExtension (via mock) handles primary button press
/// (writes unlock request to App Group UserDefaults, returns .close) and secondary button
/// press (returns .close).
@Suite("ShieldActionHandler Tests")
struct ShieldActionHandlerTests {

    /// Creates a handler with test-specific UserDefaults.
    private func makeHandler() -> (ShieldActionHandler, UserDefaults, SharedStateService) {
        let suiteName = "test.shield.action.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sharedStateService = SharedStateService(defaults: defaults)
        let handler = ShieldActionHandler(sharedStateService: sharedStateService)
        return (handler, defaults, sharedStateService)
    }

    @Test("Primary button returns .close")
    func primaryButtonReturnsClose() {
        let (handler, _, _) = makeHandler()
        let response = handler.handle(action: .primaryButtonPressed)
        #expect(response == .close)
    }

    @Test("Secondary button returns .close")
    func secondaryButtonReturnsClose() {
        let (handler, _, _) = makeHandler()
        let response = handler.handle(action: .secondaryButtonPressed)
        #expect(response == .close)
    }

    @Test("Primary button writes unlock request flag to UserDefaults")
    func primaryButtonWritesUnlockFlag() {
        let (handler, _, sharedState) = makeHandler()

        // Initially no unlock requested
        #expect(!sharedState.isUnlockRequested())

        // Press primary button
        _ = handler.handle(action: .primaryButtonPressed)

        // Unlock should be requested
        #expect(sharedState.isUnlockRequested())
    }

    @Test("Primary button writes unlock request timestamp to UserDefaults")
    func primaryButtonWritesTimestamp() {
        let (handler, _, sharedState) = makeHandler()

        // Initially no timestamp
        let initialTimestamp = sharedState.getTimestamp(for: .unlockRequestedTimestamp)
        #expect(initialTimestamp == nil)

        // Press primary button
        let beforeAction = Date()
        _ = handler.handle(action: .primaryButtonPressed)
        let afterAction = Date()

        // Timestamp should be set
        let timestamp = sharedState.getTimestamp(for: .unlockRequestedTimestamp)
        #expect(timestamp != nil)

        // Timestamp should be between before and after
        if let ts = timestamp {
            #expect(ts >= beforeAction.addingTimeInterval(-1))
            #expect(ts <= afterAction.addingTimeInterval(1))
        }
    }

    @Test("Secondary button does not write unlock request")
    func secondaryButtonNoSideEffect() {
        let (handler, _, sharedState) = makeHandler()

        // Press secondary button
        _ = handler.handle(action: .secondaryButtonPressed)

        // Unlock should NOT be requested
        #expect(!sharedState.isUnlockRequested())
    }

    @Test("Multiple primary button presses update timestamp")
    func multiplePrimaryPresses() {
        let (handler, _, sharedState) = makeHandler()

        // First press
        _ = handler.handle(action: .primaryButtonPressed)
        let firstTimestamp = sharedState.getTimestamp(for: .unlockRequestedTimestamp)

        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        // Second press
        _ = handler.handle(action: .secondaryButtonPressed) // reset in between
        _ = handler.handle(action: .primaryButtonPressed)
        let secondTimestamp = sharedState.getTimestamp(for: .unlockRequestedTimestamp)

        #expect(firstTimestamp != nil)
        #expect(secondTimestamp != nil)
        // Second timestamp should be >= first (they could be same in fast execution)
        if let first = firstTimestamp, let second = secondTimestamp {
            #expect(second >= first)
        }
    }

    @Test("Primary button after secondary still writes unlock request")
    func primaryAfterSecondary() {
        let (handler, _, sharedState) = makeHandler()

        // Press secondary first
        _ = handler.handle(action: .secondaryButtonPressed)
        #expect(!sharedState.isUnlockRequested())

        // Then press primary
        _ = handler.handle(action: .primaryButtonPressed)
        #expect(sharedState.isUnlockRequested())
    }

    @Test("ShieldActionResponseType equality")
    func responseTypeEquality() {
        #expect(ShieldActionResponseType.close == ShieldActionResponseType.close)
        #expect(ShieldActionResponseType.none == ShieldActionResponseType.none)
        #expect(ShieldActionResponseType.close != ShieldActionResponseType.none)
    }

    @Test("ShieldActionType equality")
    func actionTypeEquality() {
        #expect(ShieldActionType.primaryButtonPressed == ShieldActionType.primaryButtonPressed)
        #expect(ShieldActionType.secondaryButtonPressed == ShieldActionType.secondaryButtonPressed)
        #expect(ShieldActionType.primaryButtonPressed != ShieldActionType.secondaryButtonPressed)
    }
}
