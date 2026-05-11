import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class FilterChipSnapshotTests: XCTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_selected() {
        let view = FilterChip(label: "ALL", isSelected: true, accent: accent) {}
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
    func test_unselected() {
        let view = FilterChip(label: "HEALTH", isSelected: false, accent: accent) {}
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
