import XCTest

final class InsightsNavigationUITests: XCTestCase {
    func test_tapStatsTab_revealsInsightsHeader() throws {
        let app = XCUIApplication()
        app.launch()

        let statsTab = app.buttons["STATS tab"].firstMatch
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10))
        statsTab.tap()

        let insightsHeader = app.descendants(matching: .any).matching(identifier: "INSIGHTS").firstMatch
        XCTAssertTrue(insightsHeader.waitForExistence(timeout: 5)
                      || app.staticTexts["INSIGHTS"].waitForExistence(timeout: 5),
                      "Expected INSIGHTS header after tapping STATS tab")
    }
}
