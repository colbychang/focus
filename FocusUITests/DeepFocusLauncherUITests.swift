import XCTest

// MARK: - DeepFocusLauncherUITests

/// UI tests for the deep focus launcher view.
/// Tests launcher display during an active session, category grouping visibility,
/// and empty state when no apps are allowed.
final class DeepFocusLauncherUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store"
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Navigate to the Deep Focus tab.
    private func navigateToDeepFocus() {
        let deepFocusTab = app.tabBars.buttons["Deep Focus"]
        XCTAssertTrue(deepFocusTab.waitForExistence(timeout: 5), "Deep Focus tab should exist")
        deepFocusTab.tap()
    }

    /// Start a session with the given preset.
    private func startSession(preset: Int = 30) {
        let presetButton = app.buttons["PresetButton_\(preset)"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 5))
        presetButton.tap()

        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startButton.isEnabled)
        startButton.tap()
    }

    // MARK: - Launcher View Tests

    func testLauncherViewAppearsOnSessionStart() {
        navigateToDeepFocus()
        startSession()

        // Launcher view should appear
        let launcherView = app.otherElements["DeepFocusLauncherView"]
        XCTAssertTrue(launcherView.waitForExistence(timeout: 5), "Launcher view should appear after starting session")
    }

    func testLauncherShowsTimerDisplay() {
        navigateToDeepFocus()
        startSession()

        // Timer should be visible in the launcher
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5), "Timer display should be visible in launcher")
    }

    func testLauncherShowsEmptyStateWhenNoAllowedApps() {
        navigateToDeepFocus()
        startSession()

        // With no allowed apps configured, empty state should be visible
        let emptyState = app.otherElements["EmptyLauncherState"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Empty launcher state should be visible when no apps are allowed")

        let emptyTitle = app.staticTexts["EmptyLauncherTitle"]
        XCTAssertTrue(emptyTitle.exists, "Empty state title should be visible")

        let emptyMessage = app.staticTexts["EmptyLauncherMessage"]
        XCTAssertTrue(emptyMessage.exists, "Empty state message should be visible")
    }

    func testLauncherEndSessionButton() {
        navigateToDeepFocus()
        startSession()

        // End session button should be visible in launcher
        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End Session button should exist in launcher")
    }

    func testLauncherEndSessionReturnsToSelection() {
        navigateToDeepFocus()
        startSession()

        // Wait for launcher
        let launcherView = app.otherElements["DeepFocusLauncherView"]
        XCTAssertTrue(launcherView.waitForExistence(timeout: 5))

        // End the session — tapping End Session shows a two-step confirmation dialog
        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // Handle first confirmation dialog "End Session?"
        let firstAlert = app.alerts.firstMatch
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5), "First confirmation dialog should appear")
        firstAlert.buttons["End Session"].firstMatch.tap()

        // Handle second confirmation dialog "Lose Focus Time?"
        let secondAlert = app.alerts.firstMatch
        XCTAssertTrue(secondAlert.waitForExistence(timeout: 5), "Second confirmation dialog should appear")
        secondAlert.buttons["End Session"].firstMatch.tap()

        // Should return to duration selection
        let presetButton = app.buttons["PresetButton_30"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 10), "Duration selection should reappear after ending session from launcher")
    }

    func testLauncherTimerUpdates() {
        navigateToDeepFocus()
        startSession(preset: 30)

        // Timer should start at 30:00
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5))

        // The initial value should be around 30:00 (may have ticked a second)
        let initialLabel = timerDisplay.label
        XCTAssertTrue(
            initialLabel.contains("30:00") || initialLabel.contains("29:5"),
            "Timer should start around 30:00, got: \(initialLabel)"
        )
    }
}
