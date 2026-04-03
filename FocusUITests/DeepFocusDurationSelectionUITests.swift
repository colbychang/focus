import XCTest

// MARK: - DeepFocusDurationSelectionUITests

/// UI tests for the deep focus duration selection view.
/// Tests preset buttons, custom input, mutual exclusion, and start button behavior.
final class DeepFocusDurationSelectionUITests: XCTestCase {

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

    // MARK: - Tests

    func testPresetButtonsExist() {
        navigateToDeepFocus()

        // Check for the Deep Focus tab content first
        let tabContent = app.otherElements["DeepFocusTabContent"]
        XCTAssertTrue(tabContent.waitForExistence(timeout: 5), "Deep Focus tab content should exist")

        // All 4 preset buttons should be visible
        XCTAssertTrue(app.buttons["PresetButton_30"].waitForExistence(timeout: 5), "30 min preset should exist")
        XCTAssertTrue(app.buttons["PresetButton_60"].exists, "60 min preset should exist")
        XCTAssertTrue(app.buttons["PresetButton_90"].exists, "90 min preset should exist")
        XCTAssertTrue(app.buttons["PresetButton_120"].exists, "120 min preset should exist")
    }

    func testCustomDurationFieldExists() {
        navigateToDeepFocus()

        let customField = app.textFields["CustomDurationField"]
        XCTAssertTrue(customField.waitForExistence(timeout: 5))
    }

    func testStartButtonExistsButDisabledInitially() {
        navigateToDeepFocus()

        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertFalse(startButton.isEnabled, "Start button should be disabled when no duration is selected")
    }

    func testSelectPresetEnablesStartButton() {
        navigateToDeepFocus()

        // Tap a preset
        let preset30 = app.buttons["PresetButton_30"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 5))
        preset30.tap()

        // Start button should now be enabled
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.isEnabled, "Start button should be enabled after selecting a preset")
    }

    func testSelectDifferentPresetSwitchesSelection() {
        navigateToDeepFocus()

        // Tap 30 min preset
        let preset30 = app.buttons["PresetButton_30"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 5))
        preset30.tap()

        // Tap 60 min preset
        let preset60 = app.buttons["PresetButton_60"]
        preset60.tap()

        // Start should still be enabled
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.isEnabled)
    }

    func testStartSessionShowsTimerView() {
        navigateToDeepFocus()

        // Select a preset
        let preset30 = app.buttons["PresetButton_30"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 5))
        preset30.tap()

        // Tap Start
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.isEnabled)
        startButton.tap()

        // Launcher view with timer display should appear
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 10), "Timer display should appear after starting session")

        // End session button should appear
        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End Session button should appear during active session")
    }

    func testEndSessionReturnsToSelection() {
        navigateToDeepFocus()

        // Start a session
        let preset30 = app.buttons["PresetButton_30"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 5))
        preset30.tap()

        let startButton = app.buttons["StartSessionButton"]
        startButton.tap()

        // Wait for launcher timer view
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5))

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

        // After abandoning, tab returns to duration selection (idle state)
        let presetAfter = app.buttons["PresetButton_30"]
        XCTAssertTrue(presetAfter.waitForExistence(timeout: 10), "Duration selection should reappear after ending session")
    }
}
