import Foundation
import UserNotifications

public final class NotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authState() async -> NotificationAuthState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .undetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .undetermined
        }
    }

    @discardableResult
    public func requestAuthorization() async throws -> NotificationAuthState {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ? .authorized : .denied
    }

    public func schedule(_ notification: ScheduledNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        var components = DateComponents()
        components.hour = notification.hour
        components.minute = notification.minute
        if let weekday = notification.weekday {
            components.weekday = weekday
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notification.identifier,
                                            content: content,
                                            trigger: trigger)
        try await center.add(request)
    }

    public func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    public func pendingIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(\.identifier)
    }
}
