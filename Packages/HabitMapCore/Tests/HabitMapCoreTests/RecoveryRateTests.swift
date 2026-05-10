import XCTest
import SwiftData
@testable import HabitMapCore

final class RecoveryRateTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
    }

    @MainActor
    func test_recoveryRate_allComplete_isOne() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "W", emoji: "💧", accentHex: "#3DA4FF", type: .manualOnce, targetReps: 1)
        habit.weekdayMask = 0b01111111
        ctx.insert(habit)
        let cal = Calendar.current
        for offset in 0..<30 {
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
            ctx.insert(HabitCompletion(date: date, reps: 1, habit: habit))
        }
        XCTAssertEqual(habit.recoveryRate(window: 30), 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_recoveryRate_halfComplete_isHalf() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "W", emoji: "💧", accentHex: "#3DA4FF", type: .manualOnce, targetReps: 1)
        habit.weekdayMask = 0b01111111
        ctx.insert(habit)
        let cal = Calendar.current
        for offset in 0..<30 where offset % 2 == 0 {
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
            ctx.insert(HabitCompletion(date: date, reps: 1, habit: habit))
        }
        XCTAssertEqual(habit.recoveryRate(window: 30), 0.5, accuracy: 0.05)
    }

    @MainActor
    func test_recoveryRate_restDaysExcluded() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "GYM", emoji: "🏋️", accentHex: "#FF6B9A", type: .manualOnce, targetReps: 1)
        habit.weekdayMask = 0b01111111
        habit.restDayMask = 0b01100000  // Sat=bit5, Sun=bit6
        ctx.insert(habit)
        let cal = Calendar.current
        for offset in 0..<30 {
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
            if !habit.isRestDay(date) {
                ctx.insert(HabitCompletion(date: date, reps: 1, habit: habit))
            }
        }
        XCTAssertEqual(habit.recoveryRate(window: 30), 1.0, accuracy: 0.001)
    }
}
