import XCTest

// MARK: - FocusNotificationUITests

/// UI tests for in-app focus mode notification banners.
/// Verifies VAL-CROSS-008: When a scheduled focus mode starts or ends
/// while the user is in the app, an in-app banner appears.
final class FocusNotificationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Banner Appearance Tests

    /// Test: Focus mode activation shows a banner with profile name.
    func testActivationBannerAppears() throws {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store",
            "--show-focus-notification",
            "--notification-profile-name", "Work"
        ]
        app.launch()

        let exists = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(exists, "App should be in foreground")

        // The notification banner should appear
        let banner = app.otherElements["FocusNotificationBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Focus notification banner should appear")

        // Verify banner shows the correct profile name
        let messageText = app.staticTexts["BannerMessage"]
        XCTAssertTrue(messageText.waitForExistence(timeout: 3), "Banner message should exist")
        XCTAssertEqual(messageText.label, "Work Focus activated")

        // Verify subtitle
        let subtitleText = app.staticTexts["BannerSubtitle"]
        XCTAssertTrue(subtitleText.exists, "Banner subtitle should exist")
        XCTAssertEqual(subtitleText.label, "Focus mode is now active")
    }

    /// Test: Focus mode deactivation shows an ended banner.
    func testDeactivationBannerAppears() throws {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store",
            "--show-focus-notification",
            "--notification-type-ended",
            "--notification-profile-name", "Evening"
        ]
        app.launch()

        let exists = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(exists, "App should be in foreground")

        // The notification banner should appear
        let banner = app.otherElements["FocusNotificationBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Focus notification banner should appear")

        // Verify banner shows the correct message
        let messageText = app.staticTexts["BannerMessage"]
        XCTAssertTrue(messageText.waitForExistence(timeout: 3), "Banner message should exist")
        XCTAssertEqual(messageText.label, "Evening Focus ended")

        // Verify subtitle
        let subtitleText = app.staticTexts["BannerSubtitle"]
        XCTAssertTrue(subtitleText.exists, "Banner subtitle should exist")
        XCTAssertEqual(subtitleText.label, "Focus mode has ended")
    }

    /// Test: Banner can be dismissed by tapping the dismiss button.
    func testBannerCanBeDismissed() throws {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store",
            "--show-focus-notification",
            "--notification-profile-name", "Work"
        ]
        app.launch()

        let exists = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(exists, "App should be in foreground")

        // Wait for banner to appear
        let banner = app.otherElements["FocusNotificationBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Banner should appear")

        // Tap dismiss button
        let dismissButton = app.buttons["BannerDismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3), "Dismiss button should exist")
        dismissButton.tap()

        // Banner should disappear
        // Give time for animation
        let disappeared = banner.waitForNonExistence(timeout: 3)
        XCTAssertTrue(disappeared, "Banner should disappear after dismiss")
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    /// Waits for the element to no longer exist.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
