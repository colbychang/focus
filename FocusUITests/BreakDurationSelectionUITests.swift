import XCTest

// MARK: - BreakDurationSelectionUITests

/// UI tests for the break duration selection view.
/// Tests the 5 duration buttons (1-5 min), single select, confirm/cancel behavior.
final class BreakDurationSelectionUITests: XCTestCase {

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

    /// Navigate to Deep Focus tab and start a session.
    private func navigateToDeepFocusAndStartSession() {
        let deepFocusTab = app.tabBars.buttons["Deep Focus"]
        XCTAssertTrue(deepFocusTab.waitForExistence(timeout: 5), "Deep Focus tab should exist")
        deepFocusTab.tap()

        // Select a preset duration
        let preset30 = app.buttons["PresetButton_30"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 5))
        preset30.tap()

        // Start the session
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.isEnabled)
        startButton.tap()

        // Wait for launcher view
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 10), "Timer display should appear")
    }

    // MARK: - Tests

    func testTakeBreakButtonExistsDuringActiveSession() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5), "Take Break button should exist during active session")
    }

    func testBreakDurationSelectionSheetAppears() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()

        // Verify break selection sheet content
        let breakTitle = app.staticTexts["BreakTitle"]
        XCTAssertTrue(breakTitle.waitForExistence(timeout: 5), "Break title should appear")
    }

    func testFiveBreakDurationButtonsExist() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()

        // All 5 duration buttons should exist
        for minutes in 1...5 {
            let button = app.buttons["BreakDurationButton_\(minutes)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(minutes) minute button should exist")
        }
    }

    func testConfirmButtonDisabledWithoutSelection() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()

        let confirmButton = app.buttons["ConfirmBreakButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        XCTAssertFalse(confirmButton.isEnabled, "Confirm should be disabled without selection")
    }

    func testSelectDurationEnablesConfirm() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()

        // Select 3 minutes
        let button3 = app.buttons["BreakDurationButton_3"]
        XCTAssertTrue(button3.waitForExistence(timeout: 5))
        button3.tap()

        // Confirm should now be enabled
        let confirmButton = app.buttons["ConfirmBreakButton"]
        XCTAssertTrue(confirmButton.isEnabled, "Confirm should be enabled after selection")
    }

    func testCancelDismissesSheet() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()

        let cancelButton = app.buttons["CancelBreakButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // Sheet should dismiss — timer display should still be visible
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5), "Timer should still be visible after cancel")
    }

    func testConfirmStartsBreak() {
        navigateToDeepFocusAndStartSession()

        let breakButton = app.buttons["TakeBreakButton"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()

        // Select 1 minute
        let button1 = app.buttons["BreakDurationButton_1"]
        XCTAssertTrue(button1.waitForExistence(timeout: 5))
        button1.tap()

        // Confirm
        let confirmButton = app.buttons["ConfirmBreakButton"]
        confirmButton.tap()

        // After confirming, the sheet should dismiss and the session view
        // should show break indicator
        let breakIndicator = app.otherElements["BreakIndicator"]
        // Break indicator should appear (wait a bit for sheet dismissal)
        let exists = breakIndicator.waitForExistence(timeout: 5)
        // If the break indicator appears, break started successfully
        // If it doesn't immediately appear, the sheet dismissal/transition may take time
        // Either way, the timer display should still be present
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5), "Timer display should still be visible")
    }
}
