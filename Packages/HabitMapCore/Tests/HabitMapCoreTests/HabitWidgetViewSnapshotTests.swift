import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class HabitWidgetViewSnapshotTests: SnapshotTestCase {
    func test_compact_systemSmall() {
        let view = HabitWidgetView(snapshot: .placeholder, isCompact: true)
            .frame(width: 158, height: 158)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_wide_systemMedium() {
        let view = HabitWidgetView(snapshot: .placeholder, isCompact: false)
            .frame(width: 338, height: 158)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_compact_allDoneToday() {
        let snap = WidgetSnapshot(consistencyPct: 100, currentStreak: 12,
                                  todayDone: 4, todayTotal: 4, accentHex: "#3DA4FF")
        let view = HabitWidgetView(snapshot: snap, isCompact: true)
            .frame(width: 158, height: 158)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
