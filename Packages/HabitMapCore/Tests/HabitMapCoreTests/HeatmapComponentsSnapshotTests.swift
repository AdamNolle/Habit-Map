import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import HabitMapCore

/// Empty/clean fixtures keep these deterministic across days: with no completions
/// every cell resolves to `.empty`, independent of the calendar date.
@MainActor
final class HeatmapComponentsSnapshotTests: SnapshotTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func test_masterHeatmapCard_empty() throws {
        let container = try makeContainer()
        let page = HabitPage(name: "Health", emoji: "🩺", accentHex: "#2BFF5F", sortOrder: 0)
        container.mainContext.insert(page)
        let view = MasterHeatmapCard(page: page, days: 28)
            .frame(width: 340)
            .padding(16)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_miniHeatmap_clean() throws {
        let container = try makeContainer()
        let habit = Habit(name: "RUN", emoji: "🏃", accentHex: "#2BFF5F",
                          type: .manualOnce, targetReps: 1, weekdayMask: 0b1111111)
        container.mainContext.insert(habit)
        let view = MiniHeatmap(habit: habit, cellSize: 8, columns: 15, rows: 2)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
