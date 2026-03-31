import XCTest

// MARK: - GrayscaleGuideUITests

/// UI tests for the grayscale setup guide.
/// Covers VAL-FOCUS-009: The app provides a multi-step guide walking users through
/// enabling the Accessibility Shortcut for grayscale (Color Filters).
/// The guide can be dismissed to return to the previous screen.
final class GrayscaleGuideUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--auth-status", "approved", "--use-in-memory-store"]
        app.launch()

        // Navigate to Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist")
        settingsTab.tap()
    }

    // MARK: - Guide Presentation Tests

    /// Test: Grayscale guide button exists in Settings tab.
    func testGrayscaleGuideButtonExists() throws {
        let guideButton = app.buttons["GrayscaleGuideButton"]
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5), "Grayscale Guide button should exist in Settings")
    }

    /// Test: Tapping the grayscale guide button presents the guide view.
    func testGrayscaleGuidePresentation() throws {
        let guideButton = app.buttons["GrayscaleGuideButton"]
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5))
        guideButton.tap()

        // Verify guide view appears
        let guideView = app.otherElements["GrayscaleGuideView"]
        XCTAssertTrue(guideView.waitForExistence(timeout: 5), "Grayscale guide view should be presented")
    }

    // MARK: - Step Content Tests

    /// Test: First step shows correct content (Open Accessibility).
    func testFirstStepContent() throws {
        openGuide()

        // Verify step number
        let stepNumber = app.staticTexts["StepNumber_0"]
        XCTAssertTrue(stepNumber.waitForExistence(timeout: 5), "Step number should exist")

        // Verify step title
        let stepTitle = app.staticTexts["StepTitle_0"]
        XCTAssertTrue(stepTitle.exists, "Step title should exist")

        // Verify step instruction
        let stepInstruction = app.staticTexts["StepInstruction_0"]
        XCTAssertTrue(stepInstruction.exists, "Step instruction should exist")

        // Verify step icon
        let stepIcon = app.images["StepIcon_0"]
        XCTAssertTrue(stepIcon.exists, "Step icon should exist")
    }

    /// Test: Next button advances to subsequent steps with correct content.
    func testStepNavigation() throws {
        openGuide()

        // Verify we start on step 1
        let stepNumber0 = app.staticTexts["StepNumber_0"]
        XCTAssertTrue(stepNumber0.waitForExistence(timeout: 5), "Should start on step 1")

        // Tap Next to go to step 2
        let nextButton = app.buttons["GrayscaleGuideNextButton"]
        XCTAssertTrue(nextButton.exists, "Next button should exist on first step")
        nextButton.tap()

        // Wait for step 2 content
        let stepTitle1 = app.staticTexts["StepTitle_1"]
        XCTAssertTrue(stepTitle1.waitForExistence(timeout: 3), "Step 2 title should appear")

        // Tap Next to go to step 3
        let nextButton2 = app.buttons["GrayscaleGuideNextButton"]
        XCTAssertTrue(nextButton2.waitForExistence(timeout: 3))
        nextButton2.tap()

        // Wait for step 3 content
        let stepTitle2 = app.staticTexts["StepTitle_2"]
        XCTAssertTrue(stepTitle2.waitForExistence(timeout: 3), "Step 3 title should appear")
    }

    /// Test: Back button returns to previous step.
    func testBackButton() throws {
        openGuide()

        // Go to step 2
        let nextButton = app.buttons["GrayscaleGuideNextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        // Verify step 2
        let stepTitle1 = app.staticTexts["StepTitle_1"]
        XCTAssertTrue(stepTitle1.waitForExistence(timeout: 3), "Should be on step 2")

        // Tap Back
        let backButton = app.buttons["GrayscaleGuideBackButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Back button should exist on step 2")
        backButton.tap()

        // Should be back on step 1
        let stepTitle0 = app.staticTexts["StepTitle_0"]
        XCTAssertTrue(stepTitle0.waitForExistence(timeout: 3), "Should be back on step 1")
    }

    /// Test: No back button on first step.
    func testNoBackButtonOnFirstStep() throws {
        openGuide()

        // Verify step 1 is showing
        let stepNumber0 = app.staticTexts["StepNumber_0"]
        XCTAssertTrue(stepNumber0.waitForExistence(timeout: 5))

        // Back button should not exist
        let backButton = app.buttons["GrayscaleGuideBackButton"]
        XCTAssertFalse(backButton.exists, "Back button should not exist on first step")
    }

    /// Test: Last step shows Done button instead of Next.
    func testDoneButtonOnLastStep() throws {
        openGuide()

        // Navigate through all steps (5 steps total, so tap Next 4 times)
        for _ in 0..<4 {
            let nextButton = app.buttons["GrayscaleGuideNextButton"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 3), "Next button should exist")
            nextButton.tap()
            // Small wait for animation
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Last step should show Done button
        let doneButton = app.buttons["GrayscaleGuideDoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "Done button should exist on last step")

        // Next button should not exist
        let nextButton = app.buttons["GrayscaleGuideNextButton"]
        XCTAssertFalse(nextButton.exists, "Next button should not exist on last step")
    }

    // MARK: - Dismissal Tests

    /// Test: Dismiss button (X) dismisses the guide.
    func testDismissButtonDismissesGuide() throws {
        openGuide()

        // Verify guide is showing
        let guideView = app.otherElements["GrayscaleGuideView"]
        XCTAssertTrue(guideView.waitForExistence(timeout: 5), "Guide should be visible")

        // Tap dismiss button
        let dismissButton = app.buttons["GrayscaleGuideDismissButton"]
        XCTAssertTrue(dismissButton.exists, "Dismiss button should exist")
        dismissButton.tap()

        // Guide should be dismissed — Settings should be visible again
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings should be visible after dismissal")
    }

    /// Test: Done button on last step dismisses the guide.
    func testDoneButtonDismissesGuide() throws {
        openGuide()

        // Navigate to last step
        for _ in 0..<4 {
            let nextButton = app.buttons["GrayscaleGuideNextButton"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
            nextButton.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Tap Done
        let doneButton = app.buttons["GrayscaleGuideDoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        // Guide should be dismissed — Settings should be visible again
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings should be visible after Done")
    }

    /// Test: Step progress indicators exist.
    func testStepProgressIndicators() throws {
        openGuide()

        // Progress view should exist
        let progressView = app.otherElements["StepProgressView"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 5), "Step progress view should exist")
    }

    // MARK: - Helpers

    /// Opens the grayscale guide from the Settings tab.
    private func openGuide() {
        let guideButton = app.buttons["GrayscaleGuideButton"]
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5), "Guide button should exist")
        guideButton.tap()

        let guideView = app.otherElements["GrayscaleGuideView"]
        XCTAssertTrue(guideView.waitForExistence(timeout: 5), "Guide should be presented")
    }
}
