import XCTest

final class PageCRUDUITests: XCTestCase {
    func test_openPagesManagerAndAddPage() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap the grid icon in header to open Pages Manager.
        let managerButton = app.buttons["Manage pages"].firstMatch
        XCTAssertTrue(managerButton.waitForExistence(timeout: 10))
        managerButton.tap()

        XCTAssertTrue(app.navigationBars["PAGES"].waitForExistence(timeout: 5))

        // Tap "NEW PAGE" row (accessibility label = "Add page")
        let addPageButton = app.buttons["Add page"].firstMatch
        XCTAssertTrue(addPageButton.waitForExistence(timeout: 5))
        addPageButton.tap()

        XCTAssertTrue(app.navigationBars["NEW PAGE"].waitForExistence(timeout: 5))

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("WORK")

        let createButton = app.buttons["CREATE PAGE"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        // Back to Pages Manager — WORK should appear.
        let workLabel = app.descendants(matching: .any).matching(identifier: "WORK").firstMatch
        XCTAssertTrue(workLabel.waitForExistence(timeout: 5) || app.staticTexts["WORK"].waitForExistence(timeout: 5),
                      "Expected WORK page to appear in Pages Manager")
    }
}
