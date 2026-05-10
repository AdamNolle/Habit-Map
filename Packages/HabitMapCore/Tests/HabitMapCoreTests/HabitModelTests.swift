import XCTest
import SwiftData
@testable import HabitMapCore

final class HabitModelTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
    }

    @MainActor
    func test_createPageAndHabit() throws {
        let ctx = container.mainContext
        let page = HabitPage(name: "Health", emoji: "🩺", accentHex: "#2BFF5F", sortOrder: 0)
        let habit = Habit(name: "DRINK WATER", emoji: "💧", accentHex: "#3DA4FF", type: .manualMultiple, targetReps: 4, page: page)
        ctx.insert(page)
        ctx.insert(habit)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.page?.name, "Health")
    }

    @MainActor
    func test_progressFraction_manualOnce_completed() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "MEDITATE", emoji: "🧘", accentHex: "#C77BFF", type: .manualOnce, targetReps: 1)
        ctx.insert(habit)
        let completion = HabitCompletion(date: Date.startOfToday(), reps: 1, habit: habit)
        ctx.insert(completion)
        XCTAssertEqual(habit.progressFraction(on: Date()), 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_progressFraction_manualMultiple_partial() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "WATER", emoji: "💧", accentHex: "#3DA4FF", type: .manualMultiple, targetReps: 4)
        ctx.insert(habit)
        let completion = HabitCompletion(date: Date.startOfToday(), reps: 2, habit: habit)
        ctx.insert(completion)
        XCTAssertEqual(habit.progressFraction(on: Date()), 0.5, accuracy: 0.001)
    }

    @MainActor
    func test_progressFraction_inverse_default_complete() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "NO SODA", emoji: "🥤", accentHex: "#FF6B9A", type: .inverse, targetReps: 0)
        ctx.insert(habit)
        XCTAssertEqual(habit.progressFraction(on: Date()), 1.0)
    }

    @MainActor
    func test_progressFraction_inverse_slipped() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "NO SODA", emoji: "🥤", accentHex: "#FF6B9A", type: .inverse, targetReps: 0)
        ctx.insert(habit)
        let completion = HabitCompletion(date: Date.startOfToday(), slipped: true, habit: habit)
        ctx.insert(completion)
        XCTAssertEqual(habit.progressFraction(on: Date()), 0.0)
    }

    @MainActor
    func test_cellLevel_autoHealth_partial() throws {
        let ctx = container.mainContext
        let habit = Habit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D", type: .autoHealth, targetReps: 10000)
        habit.healthMetric = .stepCount
        habit.healthGoal = 10000
        ctx.insert(habit)
        let completion = HabitCompletion(date: Date.startOfToday(), reps: 7500, habit: habit)
        ctx.insert(completion)
        XCTAssertEqual(habit.cellLevel(on: Date()), .p75)
    }

    @MainActor
    func test_cellLevel_futureDate() throws {
        let habit = Habit(name: "X", emoji: "x", accentHex: "#FFFFFF", type: .manualOnce, targetReps: 1)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(habit.cellLevel(on: tomorrow), .future)
    }
}
