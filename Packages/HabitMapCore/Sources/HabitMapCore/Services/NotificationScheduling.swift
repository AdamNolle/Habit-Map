import Foundation

public struct ScheduledNotification: Sendable, Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let weekday: Int?      // 1=Sunday ... 7=Saturday, nil = daily
    public let hour: Int
    public let minute: Int

    public init(identifier: String, title: String, body: String,
                weekday: Int? = nil, hour: Int, minute: Int) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }
}

public enum NotificationAuthState: Sendable, Equatable {
    case undetermined, authorized, denied
}

public protocol NotificationScheduling: Sendable {
    func authState() async -> NotificationAuthState
    @discardableResult
    func requestAuthorization() async throws -> NotificationAuthState
    func schedule(_ notification: ScheduledNotification) async throws
    func cancel(identifier: String) async
    func cancelAll() async
    func pendingIdentifiers() async -> [String]
}
