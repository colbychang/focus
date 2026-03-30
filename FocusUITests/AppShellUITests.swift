import XCTest

// MARK: - AppShellUITests

/// UI tests for the app shell: tab navigation and authorization flow.
/// These tests verify VAL-FOUND-004 and VAL-FOUND-005.
final class AppShellUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Authorization Flow Tests

    /// Test: When authorization is not determined, the authorization view is shown.
    func testAuthorizationViewShownOnLaunch() throws {
        // Default launch shows authorization screen (mock starts with .notDetermined)
        app.launchArguments = ["--auth-status", "notDetermined"]
        app.launch()

        // Wait for the app to settle
        let exists = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(exists, "App should be in foreground")

        // Verify the "Allow Screen Time Access" button text exists
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 10), "Allow Screen Time Access button should exist on auth view")

        // Verify authorization-specific text
        let titleText = app.staticTexts["AuthorizationTitle"]
        XCTAssertTrue(titleText.exists, "Authorization title should be visible")
    }

    /// Test: Tapping "Allow" on authorization view transitions to tab bar (approve path).
    func testAuthorizationApproveShowsTabBar() throws {
        app.launchArguments = ["--auth-status", "notDetermined", "--auth-approve"]
        app.launch()

        // Wait for "Allow Screen Time Access" button
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 5), "Allow button should exist")

        // Tap "Allow Screen Time Access"
        allowButton.tap()

        // Verify tab bar appears
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should appear after approving authorization")

        // Verify 4 tabs exist
        XCTAssertTrue(app.tabBars.buttons["Focus"].exists, "Focus tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Deep Focus"].exists, "Deep Focus tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists, "Stats tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should exist")
    }

    /// Test: Tapping "Allow" with deny behavior shows denied view (deny path).
    func testAuthorizationDenyShowsDeniedView() throws {
        app.launchArguments = ["--auth-status", "notDetermined", "--auth-deny"]
        app.launch()

        // Wait for "Allow Screen Time Access" button
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 5), "Allow button should exist")

        // Tap "Allow Screen Time Access" (which will deny)
        allowButton.tap()

        // Verify denied view elements appear
        let deniedTitle = app.staticTexts["DeniedTitle"]
        XCTAssertTrue(deniedTitle.waitForExistence(timeout: 5), "Denied title should appear after denial")

        // Verify retry button exists
        let retryButton = app.buttons["RetryAuthorizationButton"]
        XCTAssertTrue(retryButton.exists, "Retry button should exist on denied view")

        // Verify open settings button exists
        let settingsButton = app.buttons["OpenSettingsButton"]
        XCTAssertTrue(settingsButton.exists, "Open Settings button should exist on denied view")
    }

    /// Test: App launches directly to tab bar when pre-approved.
    func testPreApprovedLaunchShowsTabBar() throws {
        app.launchArguments = ["--auth-status", "approved"]
        app.launch()

        // Tab bar should be immediately visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should appear when already authorized")

        // Verify 4 tabs
        XCTAssertEqual(app.tabBars.buttons.count, 4, "Should have exactly 4 tabs")
    }

    /// Test: App shows denied view when pre-denied.
    func testPreDeniedLaunchShowsDeniedView() throws {
        app.launchArguments = ["--auth-status", "denied"]
        app.launch()

        let deniedTitle = app.staticTexts["DeniedTitle"]
        XCTAssertTrue(deniedTitle.waitForExistence(timeout: 5), "Denied title should appear when previously denied")

        let retryButton = app.buttons["RetryAuthorizationButton"]
        XCTAssertTrue(retryButton.exists, "Retry button should exist")
    }

    // MARK: - Tab Navigation Tests

    /// Test: Tab bar has 4 tabs with correct labels.
    func testTabBarHasFourTabs() throws {
        app.launchArguments = ["--auth-status", "approved"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(app.tabBars.buttons["Focus"].exists, "Focus tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Deep Focus"].exists, "Deep Focus tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists, "Stats tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should exist")
    }

    /// Test: Focus tab is selected by default.
    func testFocusTabSelectedByDefault() throws {
        app.launchArguments = ["--auth-status", "approved"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Focus tab content should be visible - check for navigation title
        let focusNavTitle = app.navigationBars["Focus"]
        XCTAssertTrue(focusNavTitle.waitForExistence(timeout: 5), "Focus navigation bar should be visible by default")
    }

    /// Test: Tab switching displays correct content.
    func testTabSwitching() throws {
        app.launchArguments = ["--auth-status", "approved"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Switch to Deep Focus tab
        app.tabBars.buttons["Deep Focus"].tap()
        let deepFocusNav = app.navigationBars["Deep Focus"]
        XCTAssertTrue(deepFocusNav.waitForExistence(timeout: 3), "Deep Focus navigation should be visible after switching")

        // Switch to Stats tab
        app.tabBars.buttons["Stats"].tap()
        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 3), "Stats navigation should be visible after switching")

        // Switch to Settings tab
        app.tabBars.buttons["Settings"].tap()
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3), "Settings navigation should be visible after switching")

        // Switch back to Focus tab (round-trip navigation)
        app.tabBars.buttons["Focus"].tap()
        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 3), "Focus navigation should be visible after returning")
    }

    /// Test: Denied view retry transitions to tab bar when retrying with approve.
    func testDeniedRetryTransitionsToTabBar() throws {
        app.launchArguments = ["--auth-status", "notDetermined", "--auth-deny", "--auth-retry-approve"]
        app.launch()

        // Wait for auth view and tap allow (will deny)
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 5), "Allow button should exist initially")
        allowButton.tap()

        // Verify denied view appears
        let deniedTitle = app.staticTexts["DeniedTitle"]
        XCTAssertTrue(deniedTitle.waitForExistence(timeout: 5), "Denied title should appear")

        // Now retry button should approve
        let retryButton = app.buttons["RetryAuthorizationButton"]
        XCTAssertTrue(retryButton.exists, "Retry button should exist")
        retryButton.tap()

        // Tab bar should appear
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should appear after retry approval")
    }
}
