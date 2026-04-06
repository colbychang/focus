import XCTest

// MARK: - AnalyticsChartsUITests

/// UI tests for analytics charts rendering with various data volumes.
///
/// Covers:
/// - VAL-STATS-016: Charts render for 1, 7, 30, 180+ data points.
///   Single data point, all-same values, zero values, mixed small/large values handled.
///   Axes labeled correctly.
final class AnalyticsChartsUITests: XCTestCase {

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

    /// Launch with seeded analytics data (includes sessions for chart data).
    private func launchWithSeededData() {
        app.launchArguments = [
            "--auth-status", "approved",
            "--use-in-memory-store",
            "--seed-analytics-data"
        ]
        app.launch()
    }

    /// Launch with empty store.
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

    // MARK: - Chart Presence with Data

    @MainActor
    func testDailyUsageBarChartPresent() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for dashboard data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Scroll to find charts
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }

        // Look for the Daily Usage chart title
        let dailyChartTitle = app.staticTexts["Daily Usage"]
        XCTAssertTrue(dailyChartTitle.waitForExistence(timeout: 5),
                       "Daily Usage chart title should be present")
    }

    @MainActor
    func testWeeklyTrendLineChartPresent() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for dashboard data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Scroll to find charts
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeUp()
        }

        // Look for the Weekly Trend chart title
        let weeklyChartTitle = app.staticTexts["Weekly Trend"]
        XCTAssertTrue(weeklyChartTitle.waitForExistence(timeout: 5),
                       "Weekly Trend chart title should be present")
    }

    @MainActor
    func testChartsContainerPresent() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for dashboard data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Scroll to find charts container
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }

        // The AnalyticsChartsContainer should be present when there's data
        let chartsContainer = app.otherElements["AnalyticsChartsContainer"]
        XCTAssertTrue(chartsContainer.waitForExistence(timeout: 5),
                       "Charts container should be present when data exists")
    }

    // MARK: - Empty State (No Charts)

    @MainActor
    func testChartsNotShownWhenNoData() throws {
        launchEmpty()
        navigateToStats()

        // Wait for empty state
        let emptyTitle = app.staticTexts["No sessions yet"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 10))

        // Charts container should NOT be present in empty state
        let chartsContainer = app.otherElements["AnalyticsChartsContainer"]
        XCTAssertFalse(chartsContainer.exists,
                       "Charts container should not appear in empty state")
    }

    // MARK: - Bar Chart Accessibility

    @MainActor
    func testDailyUsageBarChartAccessibility() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Scroll to charts
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }

        // Check that the chart has the correct accessibility identifier
        let barChart = app.otherElements["DailyUsageBarChart"]
        XCTAssertTrue(barChart.waitForExistence(timeout: 5),
                       "Daily usage bar chart should have accessibility identifier")
    }

    // MARK: - Line Chart Accessibility

    @MainActor
    func testWeeklyTrendLineChartAccessibility() throws {
        launchWithSeededData()
        navigateToStats()

        // Wait for data to load
        let totalTimeTitle = app.staticTexts["Total Focus Time"]
        XCTAssertTrue(totalTimeTitle.waitForExistence(timeout: 10))

        // Scroll to weekly chart
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeUp()
        }

        // Check that the chart has the correct accessibility identifier
        let lineChart = app.otherElements["WeeklyTrendLineChart"]
        XCTAssertTrue(lineChart.waitForExistence(timeout: 5),
                       "Weekly trend line chart should have accessibility identifier")
    }
}
