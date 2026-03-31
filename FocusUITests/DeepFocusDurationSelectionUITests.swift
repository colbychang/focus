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

        // Timer display should appear
        let timerDisplay = app.staticTexts["TimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5), "Timer display should appear after starting session")

        // End session button should appear
        let endButton = app.buttons["EndSessionButton"]
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

        // Wait for timer view
        let timerDisplay = app.staticTexts["TimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5))

        // End the session
        let endButton = app.buttons["EndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // Should return to selection (after reset)
        // The abandoned state will show briefly, then we'd need to reset
        // For now just verify the end button worked (session is no longer showing timer in active state)
        // After abandon, tab shows the selection again (idle state)
        let presetAfter = app.buttons["PresetButton_30"]
        XCTAssertTrue(presetAfter.waitForExistence(timeout: 5), "Duration selection should reappear after ending session")
    }
}
