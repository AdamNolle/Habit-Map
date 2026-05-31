import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class WeekdayPickerSnapshotTests: SnapshotTestCase {
    private func wrap(_ view: some View) -> some View {
        view.environmentObject(Haptics()).padding(16).background(Color.black).fixedSize()
    }

    func test_allOn() {
        assertSnapshot(of: wrap(WeekdayPicker(mask: .constant(0b01111111))), as: .image(precision: 0.99))
    }

    func test_weekdaysOnly() {
        assertSnapshot(of: wrap(WeekdayPicker(mask: .constant(0b00011111))), as: .image(precision: 0.99))
    }

    func test_noneSelected() {
        assertSnapshot(of: wrap(WeekdayPicker(mask: .constant(0))), as: .image(precision: 0.99))
    }
}
