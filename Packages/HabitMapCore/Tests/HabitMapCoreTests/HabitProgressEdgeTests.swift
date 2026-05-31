import XCTest
import SwiftData
@testable import HabitMapCore

/// Edge cases around progress + recovery math: division guards, autoHealth
/// goals, and recovery windows with no scheduled days.
final class HabitProgressEdgeTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
    }

    @MainActor
    private func insert(_ habit: Habit, reps: Int? = nil) {
        container.mainContext.insert(habit)
        if let reps {
            let c = HabitCompletion(date: Date.startOfToday(), reps: reps, habit: habit)
            container.mainContext.insert(c)
        }
        try? container.mainContext.save()
    }

    @MainActor
    func test_autoHealth_reachesGoal() {
        let h = Habit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D", type: .autoHealth, targetReps: 10000)
        h.healthGoal = 10000
        insert(h, reps: 10000)
        XCTAssertEqual(h.progressFraction(on: Date()), 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_autoHealth_overGoal_clampsToOne() {
        let h = Habit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D", type: .autoHealth, targetReps: 10000)
        h.healthGoal = 10000
        insert(h, reps: 25000)
        XCTAssertEqual(h.progressFraction(on: Date()), 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_autoHealth_zeroGoal_doesNotProduceNaN() {
        // Guard against 0/0: zero goal with no reps reads as 0, with reps as done.
        let h = Habit(name: "X", emoji: "x", accentHex: "#FFFFFF", type: .autoHealth, targetReps: 1)
        h.healthGoal = 0
        insert(h, reps: 0)
        let p0 = h.progressFraction(on: Date())
        XCTAssertFalse(p0.isNaN)
        XCTAssertEqual(p0, 0.0)

        let h2 = Habit(name: "Y", emoji: "y", accentHex: "#FFFFFF", type: .autoHealth, targetReps: 1)
        h2.healthGoal = 0
        insert(h2, reps: 3)
        XCTAssertEqual(h2.progressFraction(on: Date()), 1.0)
    }

    @MainActor
    func test_manualMultiple_zeroTarget_doesNotDivideByZero() {
        let h = Habit(name: "Z", emoji: "z", accentHex: "#FFFFFF", type: .manualMultiple, targetReps: 0)
        insert(h, reps: 1)
        // max(targetReps, 1) keeps the denominator at 1.
        XCTAssertEqual(h.progressFraction(on: Date()), 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_recoveryRate_allComplete_isOne() {
        let h = Habit(name: "DAILY", emoji: "d", accentHex: "#FFFFFF", type: .manualOnce, targetReps: 1)
        container.mainContext.insert(h)
        let cal = Calendar.current
        for offset in 0..<30 {
            let day = cal.date(byAdding: .day, value: -offset, to: Date.startOfToday())!
            container.mainContext.insert(HabitCompletion(date: day, reps: 1, habit: h))
        }
        try? container.mainContext.save()
        XCTAssertEqual(h.recoveryRate(window: 30), 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_recoveryRate_noScheduledDays_isOne() {
        // No scheduled days in the window → expected == 0 → defined as 1.0 (nothing to recover).
        let h = Habit(name: "NEVER", emoji: "n", accentHex: "#FFFFFF", type: .manualOnce,
                      targetReps: 1, weekdayMask: 0)
        insert(h)
        XCTAssertEqual(h.recoveryRate(window: 30), 1.0)
    }

    @MainActor
    func test_recoveryRate_halfComplete() {
        let h = Habit(name: "HALF", emoji: "h", accentHex: "#FFFFFF", type: .manualOnce, targetReps: 1)
        container.mainContext.insert(h)
        let cal = Calendar.current
        // Complete only even offsets over a 10-day window.
        for offset in stride(from: 0, to: 10, by: 2) {
            let day = cal.date(byAdding: .day, value: -offset, to: Date.startOfToday())!
            container.mainContext.insert(HabitCompletion(date: day, reps: 1, habit: h))
        }
        try? container.mainContext.save()
        XCTAssertEqual(h.recoveryRate(window: 10), 0.5, accuracy: 0.001)
    }
}
