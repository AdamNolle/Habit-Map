import XCTest
import SwiftData
@testable import HabitMapCore

final class WidgetStatsProviderTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
    }

    @MainActor
    private func makeHabit() -> Habit {
        let h = Habit(name: "RUN", emoji: "🏃", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0b1111111)
        container.mainContext.insert(h)
        return h
    }

    @MainActor
    private func complete(_ h: Habit, daysAgo: Int) {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date.startOfToday())!
        container.mainContext.insert(HabitCompletion(date: day, reps: 1, habit: h))
    }

    @MainActor
    func test_completedTodayOnly() {
        let h = makeHabit()
        complete(h, daysAgo: 0)
        try? container.mainContext.save()
        let snap = WidgetStatsProvider.snapshot(habits: [h], accentHex: "#2BFF5F")
        XCTAssertEqual(snap.todayTotal, 1)
        XCTAssertEqual(snap.todayDone, 1)
        XCTAssertTrue(snap.todayComplete)
        XCTAssertEqual(snap.currentStreak, 1)
        XCTAssertEqual(snap.consistencyPct, 100) // brand-new habit completed every day it existed (1 of 1)
        XCTAssertEqual(snap.accentHex, "#2BFF5F")
    }

    @MainActor
    func test_completedEveryDay_isFullConsistency() {
        let h = makeHabit()
        for offset in 0..<30 { complete(h, daysAgo: offset) }
        try? container.mainContext.save()
        let snap = WidgetStatsProvider.snapshot(habits: [h])
        XCTAssertEqual(snap.consistencyPct, 100)
        XCTAssertEqual(snap.currentStreak, 30)
        XCTAssertEqual(snap.todayDone, 1)
        XCTAssertEqual(snap.todayTotal, 1)
    }

    @MainActor
    func test_partialToday() {
        let a = makeHabit(); let b = makeHabit(); let c = makeHabit()
        complete(a, daysAgo: 0)
        complete(b, daysAgo: 0)
        try? container.mainContext.save()
        let snap = WidgetStatsProvider.snapshot(habits: [a, b, c])
        XCTAssertEqual(snap.todayTotal, 3)
        XCTAssertEqual(snap.todayDone, 2)
        XCTAssertFalse(snap.todayComplete)
    }

    @MainActor
    func test_emptyHabits_isSafe() {
        let snap = WidgetStatsProvider.snapshot(habits: [])
        XCTAssertEqual(snap.todayTotal, 0)
        XCTAssertEqual(snap.todayDone, 0)
        XCTAssertFalse(snap.todayComplete)
        XCTAssertEqual(snap.currentStreak, 0)
    }

    @MainActor
    func test_pausedAndArchivedExcluded() {
        let active = makeHabit()
        let paused = makeHabit(); paused.isPaused = true
        let archived = makeHabit(); archived.isArchived = true
        complete(active, daysAgo: 0)
        try? container.mainContext.save()
        let snap = WidgetStatsProvider.snapshot(habits: [active, paused, archived])
        XCTAssertEqual(snap.todayTotal, 1)
        XCTAssertEqual(snap.todayDone, 1)
    }

    func test_snapshot_codableRoundTrip() throws {
        let data = try JSONEncoder().encode(WidgetSnapshot.placeholder)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, WidgetSnapshot.placeholder)
    }

    /// The unavailable-store fallback must be neutral, not the fabricated gallery
    /// `.placeholder` numbers (bug #7).
    func test_emptySnapshot_isNeutral() {
        let snap = WidgetSnapshot.empty
        XCTAssertEqual(snap.consistencyPct, 0)
        XCTAssertEqual(snap.currentStreak, 0)
        XCTAssertEqual(snap.todayDone, 0)
        XCTAssertEqual(snap.todayTotal, 0)
        XCTAssertFalse(snap.todayComplete)
        XCTAssertEqual(snap.todayFraction, 0)
        XCTAssertNotEqual(snap, WidgetSnapshot.placeholder)
    }
}
