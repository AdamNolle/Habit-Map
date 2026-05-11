import XCTest
import SwiftData
@testable import HabitMapCore

final class StatsServiceTests: XCTestCase {
    var container: ModelContainer!
    var stats: StatsService!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        stats = StatsService()
    }

    @MainActor
    private func makeHabit(name: String = "H", weekdayMask: Int8 = 0b01111111) -> Habit {
        let habit = Habit(name: name, emoji: "x", accentHex: "#FFFFFF",
                          type: .manualOnce, targetReps: 1,
                          weekdayMask: weekdayMask)
        container.mainContext.insert(habit)
        try? container.mainContext.save()
        return habit
    }

    @MainActor
    private func completeHabit(_ habit: Habit, daysAgo: Int) {
        let cal = Calendar.current
        let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let c = HabitCompletion(date: date, reps: 1, habit: habit)
        container.mainContext.insert(c)
        try? container.mainContext.save()
    }

    @MainActor
    func test_isComplete_allHabitsDone_isTrue() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        completeHabit(a, daysAgo: 0); completeHabit(b, daysAgo: 0)
        XCTAssertTrue(stats.isComplete(on: Date(), habits: [a, b]))
    }

    @MainActor
    func test_isComplete_oneHabitMissing_isFalse() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        completeHabit(a, daysAgo: 0)
        XCTAssertFalse(stats.isComplete(on: Date(), habits: [a, b]))
    }

    @MainActor
    func test_isComplete_noScheduledHabits_isFalse() {
        let restOnly = makeHabit(weekdayMask: 0)
        XCTAssertFalse(stats.isComplete(on: Date(), habits: [restOnly]))
    }

    @MainActor
    func test_currentStreak_zeroWhenAllMissed() {
        let h = makeHabit()
        XCTAssertEqual(stats.currentStreak(habits: [h]), 0)
    }

    @MainActor
    func test_currentStreak_fiveConsecutiveDays() {
        let h = makeHabit()
        for offset in 0..<5 { completeHabit(h, daysAgo: offset) }
        XCTAssertEqual(stats.currentStreak(habits: [h]), 5)
    }

    @MainActor
    func test_currentStreak_brokenByMissedDay() {
        let h = makeHabit()
        completeHabit(h, daysAgo: 0)
        completeHabit(h, daysAgo: 1)
        // day 2 missed
        completeHabit(h, daysAgo: 3)
        XCTAssertEqual(stats.currentStreak(habits: [h]), 2)
    }

    @MainActor
    func test_bestStreak_findsLongestRunEvenIfBroken() {
        let h = makeHabit()
        for offset in 10..<17 { completeHabit(h, daysAgo: offset) }
        for offset in 0..<3 { completeHabit(h, daysAgo: offset) }
        XCTAssertEqual(stats.bestStreak(habits: [h]), 7)
    }

    @MainActor
    func test_consistency_halfComplete_isHalf() {
        let h = makeHabit()
        for offset in 0..<30 where offset.isMultiple(of: 2) { completeHabit(h, daysAgo: offset) }
        XCTAssertEqual(stats.consistency(habits: [h], window: 30), 0.5, accuracy: 0.05)
    }

    @MainActor
    func test_consistency_noScheduledDays_returnsOne() {
        let h = makeHabit(weekdayMask: 0)
        XCTAssertEqual(stats.consistency(habits: [h], window: 30), 1.0)
    }

    @MainActor
    func test_averageProgress_partial() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        completeHabit(a, daysAgo: 0)
        XCTAssertEqual(stats.averageProgress(on: Date(), habits: [a, b]), 0.5, accuracy: 0.01)
    }
}
