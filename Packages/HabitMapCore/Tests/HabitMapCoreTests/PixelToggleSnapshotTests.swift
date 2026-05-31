import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelToggleSnapshotTests: SnapshotTestCase {
    func test_off() {
        let view = PixelToggle(isOn: .constant(false))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
    func test_on() {
        let view = PixelToggle(isOn: .constant(true))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
