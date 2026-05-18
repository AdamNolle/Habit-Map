import XCTest
import SwiftData
@testable import HabitMapCore

final class SlipFeatureExtractorTests: XCTestCase {
    var container: ModelContainer!
    var extractor: SlipFeatureExtractor!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        extractor = SlipFeatureExtractor()
    }

    @MainActor
    private func makeHabit(name: String = "H", weekdayMask: Int8 = 0b01111111) -> Habit {
        let habit = Habit(name: name, emoji: "x", accentHex: "#FFFFFF",
                          type: .manualOnce, targetReps: 1, weekdayMask: weekdayMask)
        container.mainContext.insert(habit)
        try? container.mainContext.save()
        return habit
    }

    @MainActor
    private func completeHabit(_ habit: Habit, daysAgo: Int, hour: Int = 9) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let loggedAt = cal.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) ?? dayStart
        let c = HabitCompletion(date: dayStart, reps: 1, loggedAt: loggedAt, habit: habit)
        container.mainContext.insert(c)
        try? container.mainContext.save()
    }

    @MainActor
    func test_emptyHabits_returnsEmpty() {
        let f = extractor.extract(habits: [])
        XCTAssertEqual(f, .empty)
    }

    @MainActor
    func test_singleHabitAllComplete_consistencyOne() {
        let h = makeHabit()
        for offset in 0..<30 { completeHabit(h, daysAgo: offset) }
        let f = extractor.extract(habits: [h])
        XCTAssertEqual(f.consistencyPct, 1.0, accuracy: 0.01)
        XCTAssertEqual(f.perHabit.count, 1)
        XCTAssertEqual(f.perHabit.first?.consistency30d ?? 0, 1.0, accuracy: 0.01)
    }

    @MainActor
    func test_idleHabit_appearsInList() {
        let h = makeHabit(name: "WATER")
        for offset in 8..<16 { completeHabit(h, daysAgo: offset) }
        let f = extractor.extract(habits: [h])
        XCTAssertTrue(f.idleHabits.contains("WATER"))
    }

    @MainActor
    func test_brandNewHabit_returnsLearning() {
        let h = makeHabit()
        let f = extractor.extract(habits: [h])
        XCTAssertTrue(f.isLearning)
    }

    @MainActor
    func test_weekdayCompletion_hasSevenEntries() {
        let h = makeHabit()
        let f = extractor.extract(habits: [h])
        XCTAssertEqual(f.weekdayCompletion.count, 7)
    }

    @MainActor
    func test_recoveryDaysAverage_computesGap() {
        let h = makeHabit()
        // Complete day 0, skip days 1-2, complete day 3 → gap = 3
        completeHabit(h, daysAgo: 3)
        completeHabit(h, daysAgo: 0)
        let f = extractor.extract(habits: [h])
        XCTAssertGreaterThan(f.recoveryDaysAverage, 0)
    }
}
