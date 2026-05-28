import XCTest

final class InsightsNavigationUITests: XCTestCase {
    func test_tapStatsTab_revealsInsightsHeader() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let statsTab = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'Stats'")).firstMatch
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()

        // v7 InsightsView hero text is "The pulse"
        let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'pulse'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Expected 'The pulse' hero text after tapping Stats tab")
    }
}
