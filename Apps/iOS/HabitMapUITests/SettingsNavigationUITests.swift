import XCTest

final class SettingsNavigationUITests: XCTestCase {
    func test_tapSetupTab_revealsSettingsHeader() throws {
        let app = XCUIApplication()
        app.launch()

        // System may present a notification permission alert when SETUP is tapped.
        // Tap "Don't Allow" / Allow to dismiss; either is fine for this test.
        addUIInterruptionMonitor(withDescription: "Notification Permission") { alert in
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap(); return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap(); return true
            }
            return false
        }

        let setupTab = app.buttons["SETUP tab"].firstMatch
        XCTAssertTrue(setupTab.waitForExistence(timeout: 10))
        setupTab.tap()
        // Force the interruption monitor to fire if there's a pending system alert.
        app.tap()

        let header = app.descendants(matching: .any).matching(identifier: "SETTINGS").firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 15)
                      || app.staticTexts["SETTINGS"].waitForExistence(timeout: 5),
                      "Expected SETTINGS header after tapping SETUP tab")
    }
}
