import XCTest

final class PageCRUDUITests: XCTestCase {
    func test_openPagesManagerAndAddPage() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap the grid icon in header to open Pages Manager.
        let managerButton = app.buttons["Manage pages"].firstMatch
        XCTAssertTrue(managerButton.waitForExistence(timeout: 10))
        managerButton.tap()

        // v7 nav title is "Pages" (sentence case)
        XCTAssertTrue(app.navigationBars["Pages"].waitForExistence(timeout: 5))

        // Tap "New page" row (accessibility label = "Add page")
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

        // Back to Pages Manager — "WORK" page appears.
        // Row text is title-cased ("Work") but accessibilityLabel is set to the raw name.
        let workLabel = app.staticTexts["WORK"].waitForExistence(timeout: 5)
            || app.staticTexts["Work"].waitForExistence(timeout: 2)
        XCTAssertTrue(workLabel, "Expected WORK page to appear in Pages Manager")
    }
}
