import XCTest

// MARK: - AnalyticsDashboardUITests

/// UI tests for the analytics dashboard, session history, session detail,
/// DeviceActivityReport container, and empty state.
///
/// Covers:
/// - VAL-STATS-001: Dashboard summary cards (total time, sessions, streak, empty state)
/// - VAL-STATS-002: DeviceActivityReport container presence
/// - VAL-STATS-003: Session history list with detail view
/// - VAL-STATS-012: Streak displayed correctly
final class AnalyticsDashboardUITests: XCTestCase {

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

    /// Launch with approved auth, in-memory store, and seeded analytics data.
    private func launchWithSeededData() {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store",
            "--seed-analytics-data"
        ]
        app.launch()
    }

    /// Launch with approved auth and empty in-memory store (no data).
    private func launchEmpty() {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store"
        ]
        app.launch()
    }

    /// Navigate to the Stats tab.
    private func navigateToStats() {
        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()
    }

    // MARK: - VAL-STATS-001: Dashboard Summary Cards

    @MainActor
    func testDashboardShowsSummaryCards() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for Stats navigation bar to appear, confirming we're on the tab
        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 5), "Stats nav bar should exist")

        // Wait for the card titles to appear (by label text)
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10), "Total Focus Time card title should be visible")

        let sessionsTitle = app.staticTexts["Sessions"]
        XCTAssertTrue(sessionsTitle.exists, "Sessions card title should exist")

        let streakTitle = app.staticTexts["Current Streak"]
        // Streak card may be below the fold
        if !streakTitle.exists {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(streakTitle.waitForExistence(timeout: 3), "Streak card title should exist")
    }

    @MainActor
    func testDashboardCardValues() throws {
        launchWithSeededData()
        navigateToStats()

        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 5))

        // Total focus time: 30m + 60m + 90m = 180m = 3h 0m
        // (only completed sessions: s1=1800, s2=3600, s4=5400)
        let totalTimeValue = app.staticTexts["3h 0m"]
        XCTAssertTrue(totalTimeValue.waitForExistence(timeout: 10), "Total focus time '3h 0m' should appear")

        // Sessions completed: 3 (s1, s2, s4 are completed; s3 is abandoned)
        let sessionsValue = app.staticTexts["3"]
        XCTAssertTrue(sessionsValue.exists, "Sessions count '3' should appear")

        // Current streak: 3 days (sessions today, yesterday, 2 days ago)
        let streakValue = app.staticTexts["3 days"]
        if !streakValue.exists {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(streakValue.waitForExistence(timeout: 3), "Streak '3 days' should appear")
    }

    // MARK: - VAL-STATS-001: Empty State

    @MainActor
    func testEmptyStateWhenNoSessions() throws {
        launchEmpty()
        navigateToStats()

        let statsNav = app.navigationBars["Stats"]
        XCTAssertTrue(statsNav.waitForExistence(timeout: 5))

        // Wait for the empty state text to appear (search by label)
        let emptyTitle = app.staticTexts["No sessions yet"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 10), "Empty state title should be visible")

        // Dashboard card titles should NOT be present
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertFalse(totalTimeTitle.exists, "Dashboard cards should not be visible in empty state")
    }

    // MARK: - VAL-STATS-002: DeviceActivityReport Container

    @MainActor
    func testDeviceActivityReportContainerPresent() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for stats to load by checking for card titles
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Scroll down to find the Screen Time section header
        let screenTimeHeader = app.staticTexts["Screen Time"]
        let scrollView = app.scrollViews.firstMatch
        if !screenTimeHeader.exists && scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeUp()
        }

        XCTAssertTrue(screenTimeHeader.waitForExistence(timeout: 5),
                       "Screen Time section should be present")
    }

    // MARK: - VAL-STATS-003: Session History

    @MainActor
    func testSessionHistoryNavigation() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Find and tap the Session History button (search by "Session History" label text)
        let historyButton = app.buttons["Session History"]
        if !historyButton.exists {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists { scrollView.swipeUp() }
        }
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5), "Session History link should exist")
        historyButton.tap()

        // Verify Session History navigation bar appears
        let historyNav = app.navigationBars["Session History"]
        XCTAssertTrue(historyNav.waitForExistence(timeout: 5), "Session History nav bar should be visible")
    }

    @MainActor
    func testSessionHistoryShowsSessions() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Navigate to session history
        let historyButton = app.buttons["Session History"]
        if !historyButton.exists {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists { scrollView.swipeUp() }
        }
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        // Verify Session History nav bar
        let historyNav = app.navigationBars["Session History"]
        XCTAssertTrue(historyNav.waitForExistence(timeout: 5))

        // Status badges should be visible (Completed or Abandoned text)
        let completedBadge = app.staticTexts["Completed"]
        XCTAssertTrue(completedBadge.waitForExistence(timeout: 5), "Should have Completed badges")
    }

    // MARK: - VAL-STATS-003: Session Detail

    @MainActor
    func testSessionDetailNavigation() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Navigate to session history
        let historyButton = app.buttons["Session History"]
        if !historyButton.exists {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists { scrollView.swipeUp() }
        }
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        let historyNav = app.navigationBars["Session History"]
        XCTAssertTrue(historyNav.waitForExistence(timeout: 5))

        // Tap first session row to navigate to detail
        let cells = app.collectionViews.firstMatch.cells
        let firstCell = cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()

        // Verify Session Detail navigation bar
        let detailNav = app.navigationBars["Session Detail"]
        XCTAssertTrue(detailNav.waitForExistence(timeout: 5), "Session Detail nav should appear")

        // Verify detail content labels exist
        let statusLabel = app.staticTexts["Status"]
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 3), "Status label should be shown")

        let modeTypeLabel = app.staticTexts["Mode Type"]
        XCTAssertTrue(modeTypeLabel.exists, "Mode Type label should be shown")

        let durationLabel = app.staticTexts["Duration"]
        XCTAssertTrue(durationLabel.exists, "Duration label should be shown")

        let bypassesLabel = app.staticTexts["Bypasses"]
        XCTAssertTrue(bypassesLabel.exists, "Bypasses label should be shown")

        let breaksLabel = app.staticTexts["Breaks"]
        XCTAssertTrue(breaksLabel.exists, "Breaks label should be shown")
    }

    @MainActor
    func testSessionDetailShowsCorrectMetadata() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Navigate to session history
        let historyButton = app.buttons["Session History"]
        if !historyButton.exists {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists { scrollView.swipeUp() }
        }
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        let historyNav = app.navigationBars["Session History"]
        XCTAssertTrue(historyNav.waitForExistence(timeout: 5))

        // Tap first session
        let cells = app.collectionViews.firstMatch.cells
        let firstCell = cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()

        // Verify Session Detail navigation bar
        let detailNav = app.navigationBars["Session Detail"]
        XCTAssertTrue(detailNav.waitForExistence(timeout: 5))

        // Verify Deep Focus mode type is shown
        let deepFocusText = app.staticTexts["Deep Focus"]
        XCTAssertTrue(deepFocusText.waitForExistence(timeout: 3), "Deep Focus mode type should be shown")
    }
}
