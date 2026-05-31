import XCTest

final class MapNavigationUITests: XCTestCase {
    func test_tapMapTab_revealsHeatMap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        // UITabBarButton labels include the role suffix on iOS: "Map tab"
        // Use tabBars query to scope to the tab bar specifically.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let mapTab = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS 'Map'")).firstMatch
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        // v7 MapView hero text is "The atlas"
        let header = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'atlas'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Expected 'The atlas' hero text after tapping Map tab")

        // "All habits" filter chip
        let allChip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'All habit'")).firstMatch
        XCTAssertTrue(allChip.waitForExistence(timeout: 5),
                      "Expected 'All habits' filter chip on MapView")
    }
}
