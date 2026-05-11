import XCTest
import SwiftData
@testable import HabitMapCore

final class InsightsEngineTests: XCTestCase {
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

    @MainActor
    private func makeHabit(name: String = "H", weekdayMask: Int8 = 0b01111111) -> Habit {
        let h = Habit(name: name, emoji: "x", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: weekdayMask)
        container.mainContext.insert(h)
        try? container.mainContext.save()
        return h
    }

    @MainActor
    private func completeHabit(_ habit: Habit, daysAgo: Int, loggedHour: Int? = nil) {
        let cal = Calendar.current
        let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let loggedAt: Date
        if let h = loggedHour {
            loggedAt = cal.date(bySettingHour: h, minute: 0, second: 0, of: date) ?? date
        } else {
            loggedAt = date
        }
        let c = HabitCompletion(date: date, reps: 1, loggedAt: loggedAt, habit: habit)
        container.mainContext.insert(c)
        try? container.mainContext.save()
    }

    // MARK: - strongestDayOfWeek

    @MainActor
    func test_strongestDayOfWeek_emitsWinOnHighRate() {
        let h = makeHabit()
        for offset in 0..<30 { completeHabit(h, daysAgo: offset) }
        let insights = engine.strongestDayOfWeek(habits: [h])
        XCTAssertFalse(insights.isEmpty)
        XCTAssertEqual(insights.first?.kind, .win)
    }

    @MainActor
    func test_strongestDayOfWeek_noEmissionBelowThreshold() {
        let h = makeHabit()
        for offset in stride(from: 0, to: 30, by: 3) { completeHabit(h, daysAgo: offset) }
        let insights = engine.strongestDayOfWeek(habits: [h])
        XCTAssertTrue(insights.isEmpty)
    }

    // MARK: - idleHabits

    @MainActor
    func test_idleHabits_emitsAfter7DaysIdleWithPriorActivity() {
        let h = makeHabit()
        for offset in 8..<16 { completeHabit(h, daysAgo: offset) }
        let insights = engine.idleHabits(habits: [h])
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.kind, .risk)
        XCTAssertEqual(insights.first?.title, "IDLE")
    }

    @MainActor
    func test_idleHabits_skipsBrandNewHabit() {
        let h = makeHabit()
        XCTAssertTrue(engine.idleHabits(habits: [h]).isEmpty)
    }

    @MainActor
    func test_idleHabits_skipsActiveHabit() {
        let h = makeHabit()
        completeHabit(h, daysAgo: 0)
        completeHabit(h, daysAgo: 2)
        XCTAssertTrue(engine.idleHabits(habits: [h]).isEmpty)
    }

    @MainActor
    func test_idleHabits_14daysSuggestsPause() {
        let h = makeHabit()
        for offset in 15..<22 { completeHabit(h, daysAgo: offset) }
        let insights = engine.idleHabits(habits: [h])
        XCTAssertEqual(insights.count, 1)
        XCTAssertTrue(insights.first!.body.contains("pause"))
    }

    // MARK: - stackingSuggestions

    @MainActor
    func test_stackingSuggestions_pairsCoOccur() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        for offset in 0..<10 {
            completeHabit(a, daysAgo: offset)
            completeHabit(b, daysAgo: offset)
        }
        let insights = engine.stackingSuggestions(habits: [a, b])
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.kind, .suggest)
    }

    @MainActor
    func test_stackingSuggestions_noPairBelowThreshold() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        for offset in 0..<10 { completeHabit(a, daysAgo: offset) }
        XCTAssertTrue(engine.stackingSuggestions(habits: [a, b]).isEmpty)
    }
}
