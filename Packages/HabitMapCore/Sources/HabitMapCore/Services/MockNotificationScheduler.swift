import Foundation

public final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    public var stubAuthState: NotificationAuthState
    public var scheduled: [ScheduledNotification] = []
    public var authRequestCount: Int = 0

    public init(stubAuthState: NotificationAuthState = .authorized) {
        self.stubAuthState = stubAuthState
    }

    public func authState() async -> NotificationAuthState { stubAuthState }

    @discardableResult
    public func requestAuthorization() async throws -> NotificationAuthState {
        authRequestCount += 1
        return stubAuthState
    }

    public func schedule(_ notification: ScheduledNotification) async throws {
        scheduled.removeAll { $0.identifier == notification.identifier }
        scheduled.append(notification)
    }

    public func cancel(identifier: String) async {
        scheduled.removeAll { $0.identifier == identifier }
    }

    public func cancelAll() async {
        scheduled.removeAll()
    }

    public func pendingIdentifiers() async -> [String] {
        scheduled.map(\.identifier)
    }
}
