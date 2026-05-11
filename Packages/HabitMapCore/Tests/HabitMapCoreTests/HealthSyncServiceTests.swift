import XCTest
import SwiftData
@testable import HabitMapCore

final class HealthSyncServiceTests: XCTestCase {
    var container: ModelContainer!
    var repo: HabitRepository!
    var provider: MockHealthKitProvider!
    var sync: HealthSyncService!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        repo = HabitRepository(context: container.mainContext)
        provider = MockHealthKitProvider(stubAuthState: .authorized,
                                         todayValues: [.stepCount: 7500])
        sync = HealthSyncService(provider: provider, repository: repo)
    }

    @MainActor
    func test_syncToday_createsCompletionForAutoHealthHabit() async throws {
        let page = try repo.createPage(name: "Health", emoji: "🩺", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D",
                                         type: .autoHealth, targetReps: 10000,
                                         weekdayMask: 0b01111111, on: page)
        habit.healthMetric = .stepCount
        habit.healthGoal = 10000
        try repo.context.save()

        await sync.syncToday()

        XCTAssertEqual(habit.completion(on: Date())?.reps, 7500)
        XCTAssertEqual(habit.completion(on: Date())?.source, .health)
    }

    @MainActor
    func test_syncToday_updatesExistingCompletion() async throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D",
                                         type: .autoHealth, targetReps: 10000,
                                         weekdayMask: 0b01111111, on: page)
        habit.healthMetric = .stepCount
        let completion = HabitCompletion(date: Date.startOfToday(), reps: 1000, habit: habit)
        repo.context.insert(completion)
        try repo.context.save()

        await sync.syncToday()

        XCTAssertEqual(habit.completion(on: Date())?.reps, 7500)
    }

    @MainActor
    func test_syncToday_skipsManualHabits() async throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        _ = try repo.createHabit(name: "WATER", emoji: "💧", accentHex: "#3DA4FF",
                                 type: .manualMultiple, targetReps: 4,
                                 weekdayMask: 0b01111111, on: page)

        await sync.syncToday()

        XCTAssertTrue(provider.queriedMetrics.isEmpty)
    }

    @MainActor
    func test_syncToday_setsLastSyncedAt() async throws {
        XCTAssertNil(sync.lastSyncedAt)
        await sync.syncToday()
        XCTAssertNotNil(sync.lastSyncedAt)
    }

    @MainActor
    func test_syncHabit_silentOnError() async throws {
        provider.isAvailable = false
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D",
                                         type: .autoHealth, targetReps: 10000,
                                         weekdayMask: 0b01111111, on: page)
        habit.healthMetric = .stepCount
        try repo.context.save()

        await sync.syncHabit(habit)

        XCTAssertNil(habit.completion(on: Date()), "No completion should be created on error")
    }
}
