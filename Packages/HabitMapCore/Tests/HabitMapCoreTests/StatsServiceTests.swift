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

    // MARK: - activeSince floor (pre-creation days must not count)

    /// Adding a brand-new habit must not retroactively collapse a page's existing streak:
    /// days before the new habit's `activeSince` should not require it.
    @MainActor
    func test_currentStreak_newHabitDoesNotCollapsePageStreak() {
        let older = makeHabit(name: "Older")
        for offset in 0..<20 { completeHabit(older, daysAgo: offset) }
        // Older habit alone: 20 consecutive complete days (today + 19 prior).
        XCTAssertEqual(stats.currentStreak(habits: [older]), 20)

        // Add a second habit created "today" with only a completion for today.
        let newer = makeHabit(name: "Newer")
        completeHabit(newer, daysAgo: 0)

        // The new habit predates none of the older run, so the page streak is preserved.
        XCTAssertEqual(stats.currentStreak(habits: [older, newer]), 20)
    }

    /// A brand-new habit (created today, completed today) is 100% consistent — the 29 days
    /// in the 30-day window that predate it must not be counted as missed.
    @MainActor
    func test_consistency_brandNewHabitCompletedToday_isFull() {
        let h = makeHabit()
        completeHabit(h, daysAgo: 0)
        XCTAssertEqual(stats.consistency(habits: [h], window: 30), 1.0, accuracy: 0.001)
    }

    /// `isActive(on:)` is false for a day before `createdAt` when there are no completions,
    /// and becomes true for that day once a completion exists on it.
    @MainActor
    func test_isActive_falseBeforeCreation_trueOnceCompletionExists() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let h = makeHabit()  // createdAt == now, no completions
        XCTAssertFalse(h.isActive(on: yesterday))
        XCTAssertTrue(h.isActive(on: Date()))

        // A completion on an earlier day lowers the floor back to that day.
        completeHabit(h, daysAgo: 1)
        XCTAssertTrue(h.isActive(on: yesterday))
    }

    // MARK: - consistencySeries activeSince floor (sparkline must not contradict the headline)

    /// A brand-new habit (created today, completed today) yields a series whose 29 pre-creation
    /// entries are `nil` — not 0.0 "misses" — so the sparkline agrees with `consistency() == 1.0`.
    @MainActor
    func test_consistencySeries_brandNewHabit_preCreationDaysAreNilNotMisses() {
        let h = makeHabit()
        completeHabit(h, daysAgo: 0)
        let series = stats.consistencySeries(habits: [h], window: 30)
        XCTAssertEqual(series.count, 30)
        // Today (newest, last entry) is complete.
        XCTAssertEqual(series.last ?? nil, 1.0)
        // The 29 days before creation are nil (no data), never 0.0 misses.
        XCTAssertTrue(series.dropLast().allSatisfy { $0 == nil })
        XCTAssertFalse(series.dropLast().contains { $0 == 0.0 })
        // The series must not contradict the headline consistency figure.
        XCTAssertEqual(stats.consistency(habits: [h], window: 30), 1.0, accuracy: 0.001)
    }

    /// An established habit's series is unaffected by the floor: every in-window day is non-nil,
    /// hits stay 1.0 and genuine misses stay 0.0 (not nil).
    @MainActor
    func test_consistencySeries_establishedHabit_hasNoNilsAndRecordsMisses() {
        let h = makeHabit()
        for offset in 0..<30 where offset.isMultiple(of: 2) { completeHabit(h, daysAgo: offset) }
        // A completion 29 days ago lowers the floor so the whole 30-day window is active.
        completeHabit(h, daysAgo: 29)
        let series = stats.consistencySeries(habits: [h], window: 30)
        XCTAssertEqual(series.count, 30)
        // Established: no day predates activeSince, so there are no nil entries.
        XCTAssertFalse(series.contains { $0 == nil })
        // Today (offset 0, completed) is a hit; yesterday (offset 1, missed) is a recorded 0.0.
        XCTAssertEqual(series.last ?? nil, 1.0)
        XCTAssertEqual(series[series.count - 2], 0.0)
    }
}
