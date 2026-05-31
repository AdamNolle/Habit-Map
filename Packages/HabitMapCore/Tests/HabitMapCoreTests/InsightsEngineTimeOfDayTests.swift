import XCTest
import SwiftData
@testable import HabitMapCore

/// Covers the two previously-untested InsightsEngine paths: `timeOfDaySkipRisk`
/// and the `generate` orchestrator. Uses a fixed `asOf` so the 29-day window
/// (offsets 1..<30 from 2024-02-01, a Thursday) contains exactly four Mondays:
/// 2024-01-08 / 15 / 22 / 29 — enough to clear the `attempts >= 4` gate.
final class InsightsEngineTimeOfDayTests: XCTestCase {
    var container: ModelContainer!
    var engine: InsightsEngine!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        engine = InsightsEngine()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = 12
        return Calendar.current.date(from: comps)!
    }

    private var asOf: Date { date(2024, 2, 1) } // Thursday
    private var mondays: [Date] { [date(2024, 1, 8), date(2024, 1, 15), date(2024, 1, 22), date(2024, 1, 29)] }

    @MainActor
    private func mondayHabit() -> Habit {
        let h = Habit(name: "RUN", emoji: "🏃", accentHex: "#2BFF5F",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0b0000001) // Monday only
        container.mainContext.insert(h)
        try? container.mainContext.save()
        return h
    }

    @MainActor
    private func complete(_ habit: Habit, on day: Date, hour: Int = 8) {
        let logged = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        container.mainContext.insert(HabitCompletion(date: day, reps: 1, loggedAt: logged, habit: habit))
        try? container.mainContext.save()
    }

    @MainActor
    func test_timeOfDaySkipRisk_emitsWhenDayAlwaysSkipped() {
        let h = mondayHabit() // never completed → every Monday is a skip
        let insights = engine.timeOfDaySkipRisk(habits: [h], asOf: asOf)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.kind, .risk)
        XCTAssertEqual(insights.first?.title, "SLIP WINDOW")
    }

    @MainActor
    func test_timeOfDaySkipRisk_noEmitWhenDayAlwaysCompleted() {
        let h = mondayHabit()
        for monday in mondays { complete(h, on: monday) }
        XCTAssertTrue(engine.timeOfDaySkipRisk(habits: [h], asOf: asOf).isEmpty)
    }

    @MainActor
    func test_generate_emptyHabits_returnsEmpty() {
        XCTAssertTrue(engine.generate(habits: [], asOf: asOf).isEmpty)
    }

    @MainActor
    func test_generate_includesTimeOfDayInsight() {
        let h = mondayHabit()
        let all = engine.generate(habits: [h], asOf: asOf)
        XCTAssertTrue(all.contains { $0.title == "SLIP WINDOW" })
    }

    @MainActor
    func test_generate_isUnionOfGenerators() {
        let h = mondayHabit()
        let combined = engine.generate(habits: [h], asOf: asOf).count
        let parts = engine.strongestDayOfWeek(habits: [h], asOf: asOf).count
            + engine.idleHabits(habits: [h], asOf: asOf).count
            + engine.stackingSuggestions(habits: [h], asOf: asOf).count
            + engine.timeOfDaySkipRisk(habits: [h], asOf: asOf).count
        XCTAssertEqual(combined, parts)
    }
}
