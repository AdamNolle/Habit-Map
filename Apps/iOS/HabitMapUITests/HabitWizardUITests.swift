import XCTest

final class HabitWizardUITests: XCTestCase {
    func test_createHabitViaWizard() throws {
        let app = XCUIApplication()
        app.launch()

        // FAB accessibility label is "Add habit to <PAGE>"; match by prefix.
        let fab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add habit'")).firstMatch
        XCTAssertTrue(fab.waitForExistence(timeout: 10))
        fab.tap()

        XCTAssertTrue(app.navigationBars["NEW HABIT"].waitForExistence(timeout: 5))

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("STRETCH")

        let next = app.buttons["NEXT"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        // Step 2: pick MANUAL ONCE
        let onceRow = app.buttons["ONCE A DAY"].firstMatch
        if onceRow.waitForExistence(timeout: 3) { onceRow.tap() }

        app.buttons["NEXT"].firstMatch.tap()

        // Step 3: create
        let create = app.buttons["CREATE"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        // Back on Today, STRETCH habit appears.
        let stretchLabel = app.descendants(matching: .any).matching(identifier: "STRETCH").firstMatch
        XCTAssertTrue(stretchLabel.waitForExistence(timeout: 5)
                      || app.staticTexts["STRETCH"].waitForExistence(timeout: 5),
                      "Expected STRETCH habit row to appear after wizard")
    }
}
