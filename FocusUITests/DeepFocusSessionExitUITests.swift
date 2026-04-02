import XCTest

// MARK: - DeepFocusSessionExitUITests

/// UI tests for the deep focus session exit dialog flow.
/// Tests the two-step confirmation dialog:
/// 1. First confirmation: "Are you sure?"
/// 2. Second confirmation: "You will lose X minutes of accumulated focus time."
/// Both cancel paths return to the active session.
final class DeepFocusSessionExitUITests: XCTestCase {

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

    // MARK: - End Session Button Exists

    func testEndSessionButtonExistsDuringActiveSession() {
        navigateToDeepFocusAndStartSession()

        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), "End Session button should exist during active session")
    }

    // MARK: - First Confirmation Dialog

    func testEndSessionShowsFirstConfirmationDialog() {
        navigateToDeepFocusAndStartSession()

        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // First confirmation dialog should appear
        let alert = app.alerts["End Session?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "First confirmation dialog should appear")

        // Dialog should have both Cancel and End Session buttons
        XCTAssertTrue(alert.buttons["Cancel"].exists, "Cancel button should exist in alert")
        XCTAssertTrue(alert.buttons["End Session"].exists, "End Session button should exist in alert")
    }

    // MARK: - Cancel First Dialog

    func testCancelFirstDialogReturnsToActiveSession() {
        navigateToDeepFocusAndStartSession()

        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // Wait for alert
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))

        // Tap Cancel in the alert
        alert.buttons["Cancel"].firstMatch.tap()

        // Should return to active session - timer display should still be visible
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5), "Timer display should still be visible after cancel")
    }

    // MARK: - Second Confirmation Dialog

    func testConfirmFirstShowsSecondConfirmationDialog() {
        navigateToDeepFocusAndStartSession()

        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // First confirmation
        let firstAlert = app.alerts.firstMatch
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5))

        // Confirm first dialog - tap the destructive "End Session" button in the alert
        firstAlert.buttons["End Session"].firstMatch.tap()

        // Second confirmation should appear with warning about losing time
        let secondAlert = app.alerts.firstMatch
        XCTAssertTrue(secondAlert.waitForExistence(timeout: 5), "Second confirmation dialog should appear")

        // Verify the second alert has the "Lose Focus Time?" title
        let loseTimeLabel = secondAlert.staticTexts["Lose Focus Time?"]
        XCTAssertTrue(loseTimeLabel.exists, "Second dialog should show 'Lose Focus Time?' title")
    }

    // MARK: - Cancel Second Dialog

    func testCancelSecondDialogReturnsToActiveSession() {
        navigateToDeepFocusAndStartSession()

        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // First confirmation
        let firstAlert = app.alerts.firstMatch
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5))

        // Confirm first
        firstAlert.buttons["End Session"].firstMatch.tap()

        // Wait for second dialog
        let secondAlert = app.alerts.firstMatch
        XCTAssertTrue(secondAlert.waitForExistence(timeout: 5))

        // Cancel second dialog
        secondAlert.buttons["Cancel"].firstMatch.tap()

        // Should return to active session
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 5), "Timer display should still be visible after cancelling second dialog")
    }

    // MARK: - Confirm Both Dialogs Ends Session

    func testConfirmBothDialogsEndsSession() {
        navigateToDeepFocusAndStartSession()

        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))
        endButton.tap()

        // First confirmation
        let firstAlert = app.alerts.firstMatch
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5))

        // Confirm first
        firstAlert.buttons["End Session"].firstMatch.tap()

        // Second confirmation
        let secondAlert = app.alerts.firstMatch
        XCTAssertTrue(secondAlert.waitForExistence(timeout: 5))

        // Confirm second (this should end the session)
        secondAlert.buttons["End Session"].firstMatch.tap()

        // Session should end - should go back to duration selection
        let startButton = app.buttons["StartSessionButton"]
        let exists = startButton.waitForExistence(timeout: 10)
        // Either we see the start button (idle state) or we no longer see the timer
        if !exists {
            // Check if timer display is gone (session ended)
            let timerGone = !app.staticTexts["LauncherTimerDisplay"].exists
            XCTAssertTrue(timerGone, "Session should have ended after confirming both dialogs")
        }
    }
}
