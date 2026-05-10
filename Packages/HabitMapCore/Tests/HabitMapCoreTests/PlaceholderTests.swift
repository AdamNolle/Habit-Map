import XCTest
@testable import HabitMapCore

final class PlaceholderTests: XCTestCase {
    func test_versionExists() {
        XCTAssertEqual(HabitMapCore.version, "0.1.0")
    }
}
