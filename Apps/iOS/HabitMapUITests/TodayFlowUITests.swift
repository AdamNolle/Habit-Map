import XCTest

final class TodayFlowUITests: XCTestCase {
    func test_launchesAndShowsHealthPage() throws {
        let app = XCUIApplication()
        app.launch()

        // Habit name accessibility label is set on the PixelText inside HabitRow.
        let exists = app.descendants(matching: .any)
            .matching(identifier: "DRINK WATER")
            .firstMatch
            .waitForExistence(timeout: 10)
            || app.staticTexts["DRINK WATER"].waitForExistence(timeout: 2)
        XCTAssertTrue(exists, "Expected DRINK WATER habit row to appear on Today screen")
    }
}
