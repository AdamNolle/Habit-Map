import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class WeekdayPickerSnapshotTests: XCTestCase {
    func test_allOn() {
        let view = WeekdayPicker(mask: .constant(0b01111111))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_weekdaysOnly() {
        let view = WeekdayPicker(mask: .constant(0b00011111))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_noneSelected() {
        let view = WeekdayPicker(mask: .constant(0))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
