import XCTest

final class TodayFlowUITests: XCTestCase {
    func test_launchesAndShowsHealthPage() throws {
        let app = XCUIApplication()
        app.launch()

        // Habits are displayed title-cased in HabitRow (e.g. "Drink Water").
        let exists = app.staticTexts["Drink Water"].waitForExistence(timeout: 10)
            || app.descendants(matching: .any).matching(identifier: "Drink Water").firstMatch
                .waitForExistence(timeout: 2)
        XCTAssertTrue(exists, "Expected Drink Water habit row to appear on Today screen")
    }
}
