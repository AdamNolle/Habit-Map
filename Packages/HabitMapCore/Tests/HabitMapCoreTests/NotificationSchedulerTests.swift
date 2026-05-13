import XCTest
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
}
