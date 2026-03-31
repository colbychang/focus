import XCTest

// MARK: - FocusModeUITests

/// UI tests for focus mode CRUD flows.
/// Validates VAL-FOCUS-001, VAL-FOCUS-002, and VAL-FOCUS-010.
final class FocusModeUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with approved auth to skip authorization flow
        // Use in-memory store to ensure clean state for each test
        app.launchArguments = ["--auth-status", "approved", "--use-in-memory-store"]
    }

    // MARK: - Empty State Tests

    /// Test: Empty state is shown when no focus modes exist.
    func testEmptyStateVisible() throws {
        app.launch()

        // Focus tab is selected by default, wait for it
        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 5), "Focus navigation bar should be visible")

        // Verify empty state text
        let emptyText = app.staticTexts["EmptyStateText"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "Empty state text should be visible")

        // Verify the empty state create button
        let createButton = app.buttons["EmptyStateCreateButton"]
        XCTAssertTrue(createButton.exists, "Empty state create button should exist")
    }

    /// Test: Toolbar + button exists in empty state.
    func testCreateButtonExistsInToolbar() throws {
        app.launch()

        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 5))

        let createButton = app.buttons["CreateFocusModeButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button should exist in toolbar")
    }

    // MARK: - Create Flow Tests

    /// Test: Create a profile via the toolbar button. Profile appears in list after creation.
    func testCreateProfileFlow() throws {
        app.launch()

        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 5))

        // Tap create button in toolbar
        let createButton = app.buttons["CreateFocusModeButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        // Verify create view appears
        let createView = app.otherElements["FocusModeCreateView"]
        XCTAssertTrue(createView.waitForExistence(timeout: 5), "Create view should appear")

        // Enter name
        let nameField = app.textFields["NameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name text field should exist")
        nameField.tap()
        nameField.typeText("Work")

        // Tap save
        let saveButton = app.buttons["SaveButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()

        // Verify profile appears in list (create view dismissed)
        let profileRow = app.cells.staticTexts["ProfileName_Work"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5), "Profile 'Work' should appear in list after creation")

        // Verify empty state is no longer shown
        let emptyText = app.staticTexts["EmptyStateText"]
        XCTAssertFalse(emptyText.exists, "Empty state should not be visible after creating a profile")
    }

    /// Test: Create profile via empty state button.
    func testCreateProfileFromEmptyState() throws {
        app.launch()

        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 5))

        // Tap empty state create button
        let emptyCreateButton = app.buttons["EmptyStateCreateButton"]
        XCTAssertTrue(emptyCreateButton.waitForExistence(timeout: 5))
        emptyCreateButton.tap()

        // Enter name and save
        let nameField = app.textFields["NameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Evening")

        app.buttons["SaveButton"].tap()

        // Verify profile appears in list
        let profileRow = app.cells.staticTexts["ProfileName_Evening"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5), "Profile 'Evening' should appear in list")
    }

    /// Test: Cancel on create view dismisses without creating.
    func testCancelCreateDismissesSheet() throws {
        app.launch()

        let focusNav = app.navigationBars["Focus"]
        XCTAssertTrue(focusNav.waitForExistence(timeout: 5))

        // Tap create
        let createButton = app.buttons["CreateFocusModeButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        // Verify create view appears
        let nameField = app.textFields["NameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))

        // Tap cancel
        let cancelButton = app.buttons["CancelButton"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        cancelButton.tap()

        // Verify empty state still shown (nothing was created)
        let emptyText = app.staticTexts["EmptyStateText"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "Empty state should remain after cancelling create")
    }

    // MARK: - Delete Flow Tests

    /// Test: Swipe-to-delete shows confirmation, confirming deletes the profile.
    func testDeleteWithConfirmation() throws {
        app.launch()

        // Create a profile first
        createProfile(named: "Work")

        // Verify profile exists in list
        let profileRow = app.staticTexts["ProfileName_Work"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))

        // Swipe to delete on the button/row element
        let rowButton = app.buttons["FocusModeRow_Work"]
        XCTAssertTrue(rowButton.waitForExistence(timeout: 3))
        rowButton.swipeLeft()

        // Tap the delete button from swipe action (use firstMatch since there could be duplicates)
        let swipeDeleteButton = app.buttons.matching(identifier: "Delete").firstMatch
        XCTAssertTrue(swipeDeleteButton.waitForExistence(timeout: 3), "Delete swipe action should appear")
        swipeDeleteButton.tap()

        // Confirmation alert should appear - use the alert's delete button
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Delete confirmation alert should appear")
        let confirmButton = alert.buttons.matching(identifier: "Delete").firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Confirm delete button should appear in alert")
        confirmButton.tap()

        // Verify profile is gone and empty state returns
        let emptyText = app.staticTexts["EmptyStateText"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "Empty state should return after deleting last profile")
    }

    /// Test: Swipe-to-delete cancel preserves the profile.
    func testDeleteWithCancel() throws {
        app.launch()

        // Create a profile first
        createProfile(named: "Work")

        // Verify profile exists
        let profileRow = app.staticTexts["ProfileName_Work"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))

        // Swipe to delete on the button/row element
        let rowButton = app.buttons["FocusModeRow_Work"]
        XCTAssertTrue(rowButton.waitForExistence(timeout: 3))
        rowButton.swipeLeft()

        // Tap the delete button from swipe action (use firstMatch since there could be duplicates)
        let swipeDeleteButton = app.buttons.matching(identifier: "Delete").firstMatch
        XCTAssertTrue(swipeDeleteButton.waitForExistence(timeout: 3))
        swipeDeleteButton.tap()

        // Cancel the confirmation - use the alert's cancel button
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "Delete confirmation alert should appear")
        let cancelButton = alert.buttons.matching(identifier: "Cancel").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Cancel button should appear in confirmation alert")
        cancelButton.tap()

        // Verify profile is still there
        XCTAssertTrue(profileRow.waitForExistence(timeout: 3), "Profile should still exist after cancelling delete")
    }

    // MARK: - Helpers

    /// Creates a focus mode profile through the UI.
    private func createProfile(named name: String) {
        let createButton = app.buttons["CreateFocusModeButton"]
        if !createButton.waitForExistence(timeout: 5) {
            // Try the empty state button
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

        // Wait for the sheet to dismiss
        let _ = app.cells.staticTexts["ProfileName_\(name)"].waitForExistence(timeout: 5)
    }
}
