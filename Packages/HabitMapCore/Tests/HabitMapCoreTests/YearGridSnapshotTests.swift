import XCTest
import SwiftUI
import SnapshotTesting
import SwiftData
@testable import HabitMapCore

final class YearGridSnapshotTests: SnapshotTestCase {
    @MainActor
    func test_emptyGrid() {
        let view = YearGrid(habits: [], accent: Color(hex: "#2BFF5F")) { _ in }
            .frame(width: 360, height: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
