import XCTest
import SwiftData
@testable import HabitMapCore

final class RiskForecastEngineTests: XCTestCase {
    var container: ModelContainer!
    var engine: RiskForecastEngine!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        engine = RiskForecastEngine()
    }

    @MainActor
    private func makeHabit() -> Habit {
        let h = Habit(name: "H", emoji: "x", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0b01111111)
        container.mainContext.insert(h); try? container.mainContext.save()
        return h
    }

    @MainActor
    func test_emptyHabits_returnsAllNoData() {
        let forecast = engine.forecast(habits: [])
        for row in forecast.matrix {
            for level in row { XCTAssertEqual(level, .noData) }
        }
        XCTAssertTrue(forecast.topRisks.isEmpty)
    }

    @MainActor
    func test_neverScheduled_returnsAllNoData() {
        let h = Habit(name: "H", emoji: "x", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0)
        container.mainContext.insert(h); try? container.mainContext.save()
        let forecast = engine.forecast(habits: [h])
        for row in forecast.matrix {
            for level in row { XCTAssertEqual(level, .noData) }
        }
    }

    @MainActor
    func test_matrixHasCorrectDimensions() {
        let forecast = engine.forecast(habits: [])
        XCTAssertEqual(forecast.matrix.count, 7)
        XCTAssertEqual(forecast.matrix.first?.count, 8)
    }

    @MainActor
    func test_topRisks_limitedToThree() {
        let h = makeHabit()
        let forecast = engine.forecast(habits: [h])
        XCTAssertLessThanOrEqual(forecast.topRisks.count, 3)
    }
}
