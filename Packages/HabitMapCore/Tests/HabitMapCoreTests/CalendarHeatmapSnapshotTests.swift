import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class CalendarHeatmapSnapshotTests: SnapshotTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_emptyHabits_36weeks() {
        let view = CalendarHeatmap(habits: [], accent: accent, weeks: 36, cellSize: 8)
            .padding(16)
            .background(Color.black)
            .frame(width: 380)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_emptyHabits_12weeks() {
        let view = CalendarHeatmap(habits: [], accent: accent, weeks: 12, cellSize: 10)
            .padding(16)
            .background(Color.black)
            .frame(width: 200)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_cobaltAccent() {
        let view = CalendarHeatmap(habits: [], accent: Color(hex: "#3DA4FF"), weeks: 12, cellSize: 10)
            .padding(16)
            .background(Color.black)
            .frame(width: 200)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
