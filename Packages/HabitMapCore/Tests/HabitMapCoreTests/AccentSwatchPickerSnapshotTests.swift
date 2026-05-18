import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class AccentSwatchPickerSnapshotTests: XCTestCase {
    func test_picker_default() {
        let view = AccentSwatchPicker(selectedHex: .constant("#2BFF5F"))
            .environmentObject(Haptics())
            .frame(width: 240)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
    func test_swatch_count() {
        XCTAssertEqual(AccentSwatchPicker.swatches.count, 9)
    }
}
