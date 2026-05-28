import XCTest

final class SettingsNavigationUITests: XCTestCase {
    func test_tapSetupTab_revealsSettingsHeader() throws {
        let app = XCUIApplication()
        app.launch()

        addUIInterruptionMonitor(withDescription: "Notification Permission") { alert in
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap(); return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap(); return true
            }
            return false
        }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let setupTab = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'Setup'")).firstMatch
        XCTAssertTrue(setupTab.waitForExistence(timeout: 5))
        setupTab.tap()
        app.tap()

        // v7 SettingsView renders "Settings" as a Display serif hero
        let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Settings'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 15),
                      "Expected Settings hero text after tapping Setup tab")
    }
}
