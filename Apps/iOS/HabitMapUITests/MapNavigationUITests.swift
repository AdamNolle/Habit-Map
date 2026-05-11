import XCTest

final class MapNavigationUITests: XCTestCase {
    func test_tapMapTab_revealsHeatMap() throws {
        let app = XCUIApplication()
        app.launch()

        let mapTab = app.buttons["MAP tab"].firstMatch
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        mapTab.tap()

        let heatMapHeader = app.descendants(matching: .any).matching(identifier: "HEAT MAP").firstMatch
        XCTAssertTrue(heatMapHeader.waitForExistence(timeout: 5)
                      || app.staticTexts["HEAT MAP"].waitForExistence(timeout: 5),
                      "Expected HEAT MAP header after tapping MAP tab")

        let allChip = app.buttons["ALL"].firstMatch
        XCTAssertTrue(allChip.waitForExistence(timeout: 5),
                      "Expected ALL filter chip on MapView")
    }
}
