import XCTest

// MARK: - FocusModeActivationUITests

/// UI tests for focus mode activation/deactivation flow.
/// Validates VAL-FOCUS-006 (UI aspects): status indicator shows active/inactive, toggle works.
final class FocusModeActivationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with approved auth and in-memory store for clean state
        app.launchArguments = ["--auth-status", "approved", "--use-in-memory-store"]
    }

    // MARK: - Status Indicator Tests

    /// Test: Newly created profile shows "Inactive" status.
    func testNewProfileShowsInactiveStatus() throws {
        app.launch()

        // Create a profile
        createProfile(named: "Work")

        // Verify the inactive badge is shown
        let inactiveBadge = app.staticTexts["InactiveBadge_Work"]
        XCTAssertTrue(inactiveBadge.waitForExistence(timeout: 5), "Inactive badge should be visible for new profile")

        // Active badge should NOT be shown
        let activeBadge = app.staticTexts["ActiveBadge_Work"]
        XCTAssertFalse(activeBadge.exists, "Active badge should not be visible for new profile")
    }

    /// Test: Activation toggle button exists for each profile.
    func testActivationToggleExists() throws {
        app.launch()

        createProfile(named: "Work")

        let toggle = app.buttons["ActivationToggle_Work"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Activation toggle should exist for profile")
    }

    /// Test: Tapping activation toggle changes status from inactive to active.
    func testToggleActivatesProfile() throws {
        app.launch()

        createProfile(named: "Work")

        // Verify initially inactive
        let inactiveBadge = app.staticTexts["InactiveBadge_Work"]
        XCTAssertTrue(inactiveBadge.waitForExistence(timeout: 5), "Should start as inactive")

        // Tap the activation toggle
        let toggle = app.buttons["ActivationToggle_Work"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        // Verify now active
        let activeBadge = app.staticTexts["ActiveBadge_Work"]
        XCTAssertTrue(activeBadge.waitForExistence(timeout: 5), "Active badge should appear after toggling on")

        // Inactive badge should be gone
        let inactiveBadgeAfter = app.staticTexts["InactiveBadge_Work"]
        XCTAssertFalse(inactiveBadgeAfter.exists, "Inactive badge should not be visible when active")
    }

    /// Test: Tapping activation toggle again deactivates the profile.
    func testToggleDeactivatesProfile() throws {
        app.launch()

        createProfile(named: "Work")

        // Activate
        let toggle = app.buttons["ActivationToggle_Work"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        // Verify active
        let activeBadge = app.staticTexts["ActiveBadge_Work"]
        XCTAssertTrue(activeBadge.waitForExistence(timeout: 5), "Should be active after first toggle")

        // Deactivate
        toggle.tap()

        // Verify inactive again
        let inactiveBadge = app.staticTexts["InactiveBadge_Work"]
        XCTAssertTrue(inactiveBadge.waitForExistence(timeout: 5), "Inactive badge should appear after toggling off")

        // Active badge should be gone
        XCTAssertFalse(activeBadge.exists, "Active badge should not be visible when inactive")
    }

    /// Test: Multiple profiles can show different activation states.
    func testMultipleProfilesDifferentStates() throws {
        app.launch()

        createProfile(named: "Work")
        createProfile(named: "Evening")

        // Activate only "Work"
        let workToggle = app.buttons["ActivationToggle_Work"]
        XCTAssertTrue(workToggle.waitForExistence(timeout: 5))
        workToggle.tap()

        // Verify Work is active
        let workActive = app.staticTexts["ActiveBadge_Work"]
        XCTAssertTrue(workActive.waitForExistence(timeout: 5), "Work should be active")

        // Verify Evening is still inactive
        let eveningInactive = app.staticTexts["InactiveBadge_Evening"]
        XCTAssertTrue(eveningInactive.waitForExistence(timeout: 5), "Evening should be inactive")
    }

    // MARK: - Helpers

    /// Creates a focus mode profile through the UI.
    private func createProfile(named name: String) {
        let createButton = app.buttons["CreateFocusModeButton"]
        if !createButton.waitForExistence(timeout: 5) {
            let emptyCreateButton = app.buttons["EmptyStateCreateButton"]
            XCTAssertTrue(emptyCreateButton.waitForExistence(timeout: 3))
            emptyCreateButton.tap()
        } else {
            createButton.tap()
        }

        let nameField = app.textFields["NameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        let saveButton = app.buttons["SaveButton"]
        saveButton.tap()

        // Wait for the sheet to dismiss and profile to appear
        let _ = app.staticTexts["ProfileName_\(name)"].waitForExistence(timeout: 5)
    }
}
