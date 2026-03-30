import XCTest

final class FocusUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
