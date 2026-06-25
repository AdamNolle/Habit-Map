import XCTest
import SwiftData
@testable import HabitMapCore

final class NotificationSchedulerTests: XCTestCase {
    func test_schedule_addsToScheduled() async throws {
        let mock = MockNotificationScheduler()
        let n = ScheduledNotification(identifier: "x", title: "t", body: "b", hour: 7, minute: 0)
        try await mock.schedule(n)
        let ids = await mock.pendingIdentifiers()
        XCTAssertEqual(ids, ["x"])
    }

    func test_schedule_dedupesByIdentifier() async throws {
        let mock = MockNotificationScheduler()
        let n1 = ScheduledNotification(identifier: "x", title: "t1", body: "b", hour: 7, minute: 0)
        let n2 = ScheduledNotification(identifier: "x", title: "t2", body: "b", hour: 8, minute: 0)
        try await mock.schedule(n1); try await mock.schedule(n2)
        XCTAssertEqual(mock.scheduled.count, 1)
        XCTAssertEqual(mock.scheduled.first?.title, "t2")
    }

    func test_cancel_removesIdentifier() async throws {
        let mock = MockNotificationScheduler()
        try await mock.schedule(ScheduledNotification(identifier: "a", title: "t", body: "b", hour: 7, minute: 0))
        try await mock.schedule(ScheduledNotification(identifier: "b", title: "t", body: "b", hour: 7, minute: 0))
        await mock.cancel(identifier: "a")
        let ids = await mock.pendingIdentifiers()
        XCTAssertEqual(ids, ["b"])
    }

    func test_cancelAll_clears() async throws {
        let mock = MockNotificationScheduler()
        try await mock.schedule(ScheduledNotification(identifier: "a", title: "t", body: "b", hour: 7, minute: 0))
        await mock.cancelAll()
        let ids = await mock.pendingIdentifiers()
        XCTAssertTrue(ids.isEmpty)
    }

    func test_requestAuthorization_incrementsCounter() async throws {
        let mock = MockNotificationScheduler(stubAuthState: .authorized)
        _ = try await mock.requestAuthorization()
        XCTAssertEqual(mock.authRequestCount, 1)
    }

    func test_perHabitIdentifierScheme_dedupesAcrossUpdates() async throws {
        let mock = MockNotificationScheduler()
        let habitID = UUID()
        let id = "habitmap.habit.\(habitID.uuidString)"
        try await mock.schedule(ScheduledNotification(identifier: id, title: "v1", body: "b", hour: 7, minute: 0))
        try await mock.schedule(ScheduledNotification(identifier: id, title: "v2", body: "b", hour: 8, minute: 0))
        XCTAssertEqual(mock.scheduled.count, 1)
        XCTAssertEqual(mock.scheduled.first?.hour, 8)
    }

    // MARK: - HabitReminderPlanner (per-habit weekday scheduling)

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    func test_planner_monWedFri_schedulesOnlyThoseWeekdays() throws {
        let container = try makeContainer()
        // Internal mask: Mon=bit0, Wed=bit2, Fri=bit4.
        let habit = Habit(name: "Run", emoji: "🏃", accentHex: "#2BFF5F",
                          type: .manualOnce, targetReps: 1, weekdayMask: 0b0010101)
        habit.reminderTime = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())
        container.mainContext.insert(habit)

        let notifs = HabitReminderPlanner.notifications(for: habit, tone: .gentle)
        let weekdays = Set(notifs.compactMap(\.weekday))

        // Calendar weekdays: Mon=2, Wed=4, Fri=6.
        XCTAssertEqual(weekdays, [2, 4, 6])
        XCTAssertEqual(notifs.count, 3)
        // Rest/unscheduled days (Sun=1, Tue=3, Thu=5, Sat=7) produce no trigger.
        for restDay in [1, 3, 5, 7] { XCTAssertFalse(weekdays.contains(restDay)) }
        // Every trigger keeps the reminder time and decodes back to the habit.
        for n in notifs {
            XCTAssertEqual(n.hour, 8)
            XCTAssertEqual(n.minute, 30)
            XCTAssertEqual(HabitNotificationID.parse(n.identifier), habit.id)
        }
    }

    @MainActor
    func test_planner_everyday_schedulesSingleDailyTrigger() throws {
        let container = try makeContainer()
        let habit = Habit(name: "Water", emoji: "💧", accentHex: "#2BFF5F",
                          type: .manualOnce, targetReps: 1, weekdayMask: 0b1111111)
        habit.reminderTime = Date()
        container.mainContext.insert(habit)

        let notifs = HabitReminderPlanner.notifications(for: habit, tone: .gentle)
        XCTAssertEqual(notifs.count, 1)
        XCTAssertNil(notifs.first?.weekday) // a daily (weekday-less) trigger
    }

    @MainActor
    func test_planner_restDays_areNeverScheduled() throws {
        let container = try makeContainer()
        // Scheduled every day, but Sat (bit5) & Sun (bit6) are rest days.
        let habit = Habit(name: "Read", emoji: "📖", accentHex: "#2BFF5F",
                          type: .manualOnce, targetReps: 1,
                          weekdayMask: 0b1111111, restDayMask: 0b1100000)
        habit.reminderTime = Date()
        container.mainContext.insert(habit)

        let weekdays = Set(HabitReminderPlanner.notifications(for: habit, tone: .gentle).compactMap(\.weekday))
        XCTAssertEqual(weekdays, [2, 3, 4, 5, 6]) // Mon–Fri only
        XCTAssertFalse(weekdays.contains(1)) // Sun rest day
        XCTAssertFalse(weekdays.contains(7)) // Sat rest day
    }

    @MainActor
    func test_planner_noReminder_isEmpty() throws {
        let container = try makeContainer()
        let habit = Habit(name: "X", emoji: "x", accentHex: "#2BFF5F",
                          type: .manualOnce, targetReps: 1)
        container.mainContext.insert(habit)
        XCTAssertTrue(HabitReminderPlanner.notifications(for: habit, tone: .gentle).isEmpty)
    }
}
