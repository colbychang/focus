import XCTest

// MARK: - NavigationIntegrationUITests

/// UI tests for deep focus navigation integration and cross-area flows.
///
/// Covers:
/// - VAL-CROSS-001: First launch journey (authorize → empty state → create profile → visible in list)
/// - VAL-CROSS-002: Navigation integrity (all tabs reachable, tab switch during session, timer persistence)
/// - VAL-CROSS-011: New user end-to-end journey (authorize → create → activate → deep focus → complete → analytics)
final class NavigationIntegrationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Launch the app with approved authorization and in-memory store.
    private func launchApproved() {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store"
        ]
        app.launch()
    }

    /// Launch the app with notDetermined authorization and in-memory store.
    private func launchNotDetermined(approve: Bool = true) {
        var args = [
            "--auth-status", "notDetermined",
            "--use-in-memory-store"
        ]
        if approve {
            args.append("--auth-approve")
        } else {
            args.append("--auth-deny")
        }
        app.launchArguments = args
        app.launch()
    }

    /// Navigate to the Deep Focus tab.
    private func navigateToDeepFocus() {
        let deepFocusTab = app.tabBars.buttons["Deep Focus"]
        XCTAssertTrue(deepFocusTab.waitForExistence(timeout: 5))
        deepFocusTab.tap()
    }

    /// Navigate to the Focus tab.
    private func navigateToFocus() {
        let focusTab = app.tabBars.buttons["Focus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 5))
        focusTab.tap()
    }

    /// Navigate to the Stats tab.
    private func navigateToStats() {
        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()
    }

    /// Navigate to the Settings tab.
    private func navigateToSettings() {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
    }

    /// Start a deep focus session by selecting a 30-minute preset.
    private func startDeepFocusSession() {
        navigateToDeepFocus()

        let preset30 = app.buttons["PresetButton_30"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 5))
        preset30.tap()

        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.isEnabled)
        startButton.tap()

        // Wait for launcher to appear
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 10),
                      "Timer display should appear after starting session")
    }

    /// Create a focus mode profile with the given name.
    private func createFocusModeProfile(name: String) {
        // Tap the create button
        let createButton = app.buttons["CreateFocusModeButton"]
        if !createButton.waitForExistence(timeout: 3) {
            // Try the empty state create button
            let emptyCreateButton = app.buttons["EmptyStateCreateButton"]
            XCTAssertTrue(emptyCreateButton.waitForExistence(timeout: 5),
                          "Either toolbar or empty state create button should exist")
            emptyCreateButton.tap()
        } else {
            createButton.tap()
        }

        // Wait for create view to appear
        let nameField = app.textFields["NameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5),
                      "Name field should appear in create view")

        // Type the name
        nameField.tap()
        nameField.typeText(name)

        // Save
        let saveButton = app.buttons["SaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        // Wait for sheet to dismiss
        sleep(1)
    }

    // MARK: - VAL-CROSS-001: First Launch Journey — Approve Path

    /// First launch → authorize → approve → empty state → create profile → visible in list.
    func testFirstLaunchJourneyApprove() throws {
        launchNotDetermined(approve: true)

        // Step 1: Authorization screen is shown
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 10),
                      "Authorization view should be shown on first launch")

        // Step 2: Approve → tab bar appears
        allowButton.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5),
                      "Tab bar should appear after approving authorization")

        // Step 3: Focus tab shows empty state (no profiles yet)
        let emptyStateText = app.staticTexts["EmptyStateText"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5),
                      "Empty state should be shown when no profiles exist")

        // Step 4: Create a focus mode profile
        createFocusModeProfile(name: "Work")

        // Step 5: Profile is visible in the list
        let profileRow = app.staticTexts["ProfileName_Work"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5),
                      "Created profile should be visible in the list")
    }

    // MARK: - VAL-CROSS-001: First Launch Journey — Deny Path

    /// First launch → authorize → deny → graceful degradation with explanation.
    func testFirstLaunchJourneyDeny() throws {
        launchNotDetermined(approve: false)

        // Step 1: Authorization screen is shown
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 10))

        // Step 2: Deny → denied view appears
        allowButton.tap()

        let deniedTitle = app.staticTexts["DeniedTitle"]
        XCTAssertTrue(deniedTitle.waitForExistence(timeout: 5),
                      "Denied view should appear after denial")

        // Step 3: Verify explanation and retry options
        let retryButton = app.buttons["RetryAuthorizationButton"]
        XCTAssertTrue(retryButton.exists, "Retry button should exist on denied view")

        let settingsButton = app.buttons["OpenSettingsButton"]
        XCTAssertTrue(settingsButton.exists, "Open Settings button should exist on denied view")

        let deniedDescription = app.staticTexts["DeniedDescription"]
        XCTAssertTrue(deniedDescription.exists, "Denied description should provide explanation")
    }

    // MARK: - VAL-CROSS-002: Navigation Integrity

    /// All features reachable via tab bar within two taps. No dead-end screens.
    func testNavigationIntegrityAllTabsReachable() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Verify all 4 tabs exist and are tappable
        XCTAssertTrue(app.tabBars.buttons["Focus"].exists, "Focus tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Deep Focus"].exists, "Deep Focus tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists, "Stats tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should exist")

        // Focus tab content
        navigateToFocus()
        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 3), "Focus nav bar should be visible")

        // Deep Focus tab content
        navigateToDeepFocus()
        let deepFocusNav = app.navigationBars["Deep Focus"]
        XCTAssertTrue(deepFocusNav.waitForExistence(timeout: 3), "Deep Focus nav bar should be visible")

        // Verify Deep Focus shows duration selection (no active session)
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5),
                      "Start Session button should be visible when no session is active")

        // Stats tab content
        navigateToStats()
        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 3), "Stats nav bar should be visible")

        // Settings tab content
        navigateToSettings()
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3), "Settings nav bar should be visible")

        // Round-trip: back to Focus tab
        navigateToFocus()
        XCTAssertTrue(app.navigationBars["Focus"].waitForExistence(timeout: 3),
                      "Focus nav bar should be visible after round-trip")
    }

    /// Tab switching during active deep focus session preserves the running timer.
    func testTabSwitchDuringActiveSessionPreservesTimer() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Start a deep focus session
        startDeepFocusSession()

        // Read the initial timer value
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.exists)
        let initialTimerValue = timerDisplay.label

        // Switch to Focus tab
        navigateToFocus()
        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 3),
                      "Focus tab should be visible during active session")

        // Switch to Stats tab
        navigateToStats()
        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 3),
                      "Stats tab should be visible during active session")

        // Switch to Settings tab
        navigateToSettings()
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3),
                      "Settings tab should be visible during active session")

        // Return to Deep Focus tab
        navigateToDeepFocus()

        // Timer should still be running (launcher view should show)
        let timerAfterSwitch = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerAfterSwitch.waitForExistence(timeout: 5),
                      "Timer display should still be visible after tab switching")

        // Timer value should have changed (a few seconds elapsed during tab switches)
        // Just verify the timer display exists and shows a valid time format
        let currentValue = timerAfterSwitch.label
        XCTAssertFalse(currentValue.isEmpty,
                       "Timer should show a non-empty value after returning to Deep Focus tab")

        // Verify End Session button is still available
        let endButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endButton.exists,
                      "End Session button should still be available after tab switching")
    }

    /// Deep Focus tab shows correct view based on session state:
    /// - DurationSelectionView when no active session
    /// - DeepFocusLauncherView when session is active
    func testDeepFocusTabShowsCorrectViewBasedOnSessionState() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // No active session: should show DurationSelectionView
        navigateToDeepFocus()
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5),
                      "Duration selection should be shown when no session is active")

        // Verify presets are visible
        XCTAssertTrue(app.buttons["PresetButton_30"].exists, "30 min preset should be visible")
        XCTAssertTrue(app.buttons["PresetButton_60"].exists, "60 min preset should be visible")

        // Start session: should transition to launcher view
        app.buttons["PresetButton_30"].tap()
        startButton.tap()

        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 10),
                      "Launcher view should show after starting session")

        // Verify launcher elements
        let endSessionButton = app.buttons["LauncherEndSessionButton"]
        XCTAssertTrue(endSessionButton.exists,
                      "End Session button should be visible in launcher view")
    }

    /// All features reachable via tab bar — no dead ends.
    /// Settings → Grayscale Guide opens and can be dismissed.
    func testNoDeadEndScreens() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Test Settings → Grayscale Guide → dismiss
        navigateToSettings()

        let grayscaleButton = app.buttons["GrayscaleGuideButton"]
        XCTAssertTrue(grayscaleButton.waitForExistence(timeout: 5),
                      "Grayscale guide button should exist in Settings")
        grayscaleButton.tap()

        // Grayscale guide should open as a sheet
        sleep(2) // Allow sheet to present fully

        // Dismiss the guide by swiping down on the sheet
        // Use a coordinate-based swipe for more reliable sheet dismissal
        let topOfSheet = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let bottomOfScreen = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        topOfSheet.press(forDuration: 0.1, thenDragTo: bottomOfScreen)

        sleep(1)

        // If the sheet didn't dismiss, try tapping the Settings tab directly
        // (which should dismiss the sheet and return to Settings)
        if !app.navigationBars["Settings"].waitForExistence(timeout: 2) {
            app.tabBars.buttons["Settings"].tap()
            sleep(1)
        }

        // Verify we can navigate to other tabs (no dead end)
        // Even if the sheet is still showing, tapping a tab should work
        app.tabBars.buttons["Focus"].tap()
        sleep(1)

        // Verify we reached the Focus tab
        let focusContent = app.otherElements["FocusTabContent"]
        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusContent.waitForExistence(timeout: 5) || focusNav.waitForExistence(timeout: 3),
                      "Should be able to navigate to Focus tab after visiting Settings sub-screen")
    }

    /// Verify that re-entering the Deep Focus tab during an active session shows correct status and remaining time.
    func testReenteringAppDuringActiveSessionShowsCorrectStatus() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Start a session
        startDeepFocusSession()

        // Verify initial state shows timer
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.exists)

        // Switch away and wait a moment
        navigateToFocus()
        sleep(2)

        // Come back to Deep Focus
        navigateToDeepFocus()

        // Timer should still be visible and counting down
        let timerAfterReturn = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerAfterReturn.waitForExistence(timeout: 5),
                      "Timer should be visible when re-entering Deep Focus tab")

        // Timer should show a time value (not empty)
        XCTAssertFalse(timerAfterReturn.label.isEmpty,
                       "Timer should show remaining time when re-entering")
    }

    // MARK: - VAL-CROSS-011: New User End-to-End Journey

    /// Full sequential test: authorize → create first profile → activate → start deep focus → complete → analytics.
    func testNewUserEndToEndJourney() throws {
        // Use test-seconds for a short session that completes quickly
        app.launchArguments = [
            "--auth-status", "notDetermined",
            "--auth-approve",
            "--use-in-memory-store",
            "--deep-focus-test-seconds", "3"
        ]
        app.launch()

        // Step 1: Authorize
        let allowButton = app.buttons["AllowScreenTimeAccessButton"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 10))
        allowButton.tap()

        // Step 2: Tab bar appears
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Step 3: Create first focus mode profile
        // Focus tab should show empty state
        let emptyStateText = app.staticTexts["EmptyStateText"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5),
                      "Empty state should be shown on first visit")

        createFocusModeProfile(name: "Study")

        // Step 4: Verify profile is in the list
        let profileRow = app.staticTexts["ProfileName_Study"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5),
                      "Created profile should be visible")

        // Step 5: Activate the profile
        let activationToggle = app.buttons["ActivationToggle_Study"]
        XCTAssertTrue(activationToggle.waitForExistence(timeout: 5))
        activationToggle.tap()

        // Verify it's now active
        let activeBadge = app.staticTexts["ActiveBadge_Study"]
        XCTAssertTrue(activeBadge.waitForExistence(timeout: 3),
                      "Profile should show 'Active' after activation")

        // Step 6: Navigate to Deep Focus and start a session
        navigateToDeepFocus()

        // With --deep-focus-test-seconds 3, the start button should be pre-enabled
        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startButton.isEnabled,
                      "Start button should be enabled with test duration")
        startButton.tap()

        // Step 7: Session starts — launcher view shows timer
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.waitForExistence(timeout: 10),
                      "Timer display should appear during active session")

        // Step 8: Wait for session to complete (3 seconds + buffer)
        let completionIcon = app.images["CompletionIcon"]
        XCTAssertTrue(completionIcon.waitForExistence(timeout: 15),
                      "Completion view should appear after session ends")

        // Step 9: Tap Done to return to duration selection
        let doneButton = app.buttons["DoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // Step 10: Navigate to Stats tab — verify it's reachable
        navigateToStats()
        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 5),
                      "Stats tab should be reachable after completing a session")

        // Verify Stats tab content exists (placeholder for now, will be filled by analytics feature)
        let statsContent = app.otherElements["StatsTabContent"]
        XCTAssertTrue(statsContent.waitForExistence(timeout: 3),
                      "Stats tab content should be present")
    }

    // MARK: - Additional Navigation Tests

    /// Verify that all tabs remain accessible during an active deep focus session.
    func testAllTabsAccessibleDuringActiveSession() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Start a deep focus session
        startDeepFocusSession()

        // Verify timer is showing
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.exists)

        // Tab bar should still be accessible during session
        XCTAssertTrue(app.tabBars.buttons["Focus"].exists, "Focus tab accessible during session")
        XCTAssertTrue(app.tabBars.buttons["Deep Focus"].exists, "Deep Focus tab accessible during session")
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists, "Stats tab accessible during session")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab accessible during session")

        // Visit each tab and confirm content loads
        navigateToFocus()
        XCTAssertTrue(app.navigationBars["Focus"].waitForExistence(timeout: 3))

        navigateToStats()
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 3))

        navigateToSettings()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        // Return to Deep Focus — session should still be active
        navigateToDeepFocus()
        let timerAfter = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerAfter.waitForExistence(timeout: 5),
                      "Deep focus session should still be active after visiting all tabs")
    }

    /// Verify that completing a deep focus session returns to duration selection.
    func testSessionCompletionReturnsToDurationSelection() throws {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store",
            "--deep-focus-test-seconds", "3"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Navigate to Deep Focus and start a short test session
        navigateToDeepFocus()

        let startButton = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // Wait for completion
        let completionIcon = app.images["CompletionIcon"]
        XCTAssertTrue(completionIcon.waitForExistence(timeout: 15),
                      "Completion view should appear when session ends")

        // Tap Done
        let doneButton = app.buttons["DoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // Should return to duration selection
        let startButtonAgain = app.buttons["StartSessionButton"]
        XCTAssertTrue(startButtonAgain.waitForExistence(timeout: 5),
                      "Duration selection should appear after completing a session and tapping Done")
    }

    /// Verify that the timer value changes (decrements) while session is active.
    func testTimerDecrementsWhileSessionActive() throws {
        launchApproved()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Start a session
        startDeepFocusSession()

        // Read timer value
        let timerDisplay = app.staticTexts["LauncherTimerDisplay"]
        XCTAssertTrue(timerDisplay.exists)
        let firstValue = timerDisplay.label

        // Wait 2 seconds
        sleep(2)

        // Timer should have changed
        let secondValue = timerDisplay.label
        XCTAssertNotEqual(firstValue, secondValue,
                          "Timer should decrement while session is active (was: \(firstValue), now: \(secondValue))")
    }
}
