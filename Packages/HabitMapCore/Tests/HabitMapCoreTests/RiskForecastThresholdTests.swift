import XCTest
import SwiftData
@testable import HabitMapCore

/// Drives the skip-rate → RiskLevel mapping (previously only dimensions/empty
/// cases were tested). Same fixed-window fixture as the time-of-day tests:
/// four Mondays inside offsets 1..<30 from 2024-02-01.
final class RiskForecastThresholdTests: XCTestCase {
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

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = 12
        return Calendar.current.date(from: comps)!
    }

    private var asOf: Date { date(2024, 2, 1) }
    private var mondays: [Date] { [date(2024, 1, 8), date(2024, 1, 15), date(2024, 1, 22), date(2024, 1, 29)] }

    @MainActor
    private func mondayHabit() -> Habit {
        let h = Habit(name: "RUN", emoji: "🏃", accentHex: "#2BFF5F",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0b0000001)
        container.mainContext.insert(h); try? container.mainContext.save()
        return h
    }

    @MainActor
    func test_alwaysSkippedDay_isDanger() {
        let h = mondayHabit() // never completed → skip rate 1.0 on Mondays
        // No completions/timestamps, so skips attribute to the habit's intended (reminder)
        // time bucket — evening (18..<21 → index 4) — not the overnight sentinel (index 7).
        h.reminderTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: asOf)
        try? container.mainContext.save()
        let forecast = engine.forecast(habits: [h], asOf: asOf)
        // Monday index 0, evening bucket index 4.
        XCTAssertEqual(forecast.matrix[0][4], .danger)
        XCTAssertEqual(forecast.matrix[0][7], .noData) // overnight sentinel no longer used
        XCTAssertFalse(forecast.topRisks.isEmpty)
        XCTAssertEqual(forecast.topRisks.first?.level, .danger)
        XCTAssertEqual(forecast.topRisks.first?.weekday, 0)
        XCTAssertEqual(forecast.topRisks.first?.bucket, 4)
    }

    @MainActor
    func test_alwaysCompletedMorning_isLowRiskAndNotTopRisk() {
        let h = mondayHabit()
        for monday in mondays {
            let logged = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: monday)!
            container.mainContext.insert(HabitCompletion(date: monday, reps: 1, loggedAt: logged, habit: h))
        }
        try? container.mainContext.save()
        let forecast = engine.forecast(habits: [h], asOf: asOf)
        // Morning bucket (6..<9) is index 0, skip rate 0 → best level.
        XCTAssertEqual(forecast.matrix[0][0], .completed4)
        XCTAssertEqual(forecast.matrix[0][7], .noData) // nothing landed in the skip bucket
        XCTAssertTrue(forecast.topRisks.isEmpty)
    }
}
