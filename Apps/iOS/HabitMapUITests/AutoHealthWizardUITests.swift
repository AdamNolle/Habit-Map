import XCTest

final class AutoHealthWizardUITests: XCTestCase {
    /// Verifies the wizard reaches Step 2's Auto-fill from Health option
    /// and picks a metric. Doesn't tap CREATE because that triggers the
    /// HealthKit permission sheet which is system-modal and brittle in CI.
    func test_wizard_reachesAutoHealthOptionAndPicksSteps() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
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

        // v7 label is sentence-cased
        let autoRow = app.buttons["Auto-fill from Health"].firstMatch
        XCTAssertTrue(autoRow.waitForExistence(timeout: 5),
                      "Expected Auto-fill from Health option in Step 2")
        autoRow.tap()

        // v7 metric label is sentence-cased
        let stepsMetric = app.buttons["Steps"].firstMatch
        XCTAssertTrue(stepsMetric.waitForExistence(timeout: 5),
                      "Expected Steps metric in MetricPickerView")
        stepsMetric.tap()
    }
}
