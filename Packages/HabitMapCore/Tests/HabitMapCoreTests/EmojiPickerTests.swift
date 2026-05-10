import XCTest
@testable import HabitMapCore

final class EmojiPickerTests: XCTestCase {
    func test_catalogHasExpectedCount() {
        XCTAssertEqual(EmojiPicker.catalog.count, 64)
    }

    func test_catalogIsDeduplicated() {
        let unique = Set(EmojiPicker.catalog)
        XCTAssertEqual(unique.count, EmojiPicker.catalog.count, "Catalog has duplicate emoji")
    }

    func test_catalogContainsCommonHabits() {
        XCTAssertTrue(EmojiPicker.catalog.contains("💧"))
        XCTAssertTrue(EmojiPicker.catalog.contains("🏃"))
        XCTAssertTrue(EmojiPicker.catalog.contains("🧘"))
    }
}
