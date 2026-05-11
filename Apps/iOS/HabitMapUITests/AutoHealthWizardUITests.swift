import XCTest

final class AutoHealthWizardUITests: XCTestCase {
    /// Verifies the wizard reaches Step 2's AUTO-FILL FROM HEALTH option
    /// and picks a metric. Doesn't tap CREATE because that triggers the
    /// HealthKit permission sheet which is system-modal and brittle in CI.
    func test_wizard_reachesAutoHealthOptionAndPicksSteps() throws {
        let app = XCUIApplication()
        app.launch()

        let fab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add habit'")).firstMatch
        XCTAssertTrue(fab.waitForExistence(timeout: 10))
        fab.tap()

        XCTAssertTrue(app.navigationBars["NEW HABIT"].waitForExistence(timeout: 5))

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("WALK")

        app.buttons["NEXT"].firstMatch.tap()

        let autoRow = app.buttons["AUTO-FILL FROM HEALTH"].firstMatch
        XCTAssertTrue(autoRow.waitForExistence(timeout: 5),
                      "Expected AUTO-FILL FROM HEALTH option in Step 2")
        autoRow.tap()

        let stepsMetric = app.buttons["STEPS"].firstMatch
        XCTAssertTrue(stepsMetric.waitForExistence(timeout: 5),
                      "Expected STEPS metric in MetricPickerView")
        stepsMetric.tap()
    }
}
