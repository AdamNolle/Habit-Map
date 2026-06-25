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

/// Builds the per-habit reminder triggers for a habit. Pure (no
/// `UNUserNotificationCenter`), so it lives in the package and is unit-tested —
/// keeping the weekday mapping single-sourced through `Habit.isScheduled`.
public enum HabitReminderPlanner {
    /// Calendar weekday indices (1=Sunday…7=Saturday) on which `isScheduled` is true.
    ///
    /// Probes seven consecutive days and reuses the habit's own predicate, so the
    /// internal `Mon=bit0…Sun=bit6` ↔ Calendar `1=Sun…7=Sat` mapping can't drift.
    public static func scheduledCalendarWeekdays(
        isScheduled: (Date) -> Bool,
        calendar: Calendar = .current,
        reference: Date = Date()
    ) -> [Int] {
        let start = calendar.startOfDay(for: reference)
        var weekdays: [Int] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  isScheduled(day) else { continue }
            weekdays.append(calendar.component(.weekday, from: day))
        }
        return weekdays.sorted()
    }

    /// Reminder notifications for `habit`. Empty when the habit has no reminder, is
    /// paused, or archived. An everyday schedule yields a single daily trigger;
    /// otherwise one trigger per scheduled weekday (rest days are skipped because
    /// `Habit.isScheduled` already excludes them).
    public static func notifications(
        for habit: Habit,
        tone: NotificationTone,
        calendar: Calendar = .current,
        reference: Date = Date()
    ) -> [ScheduledNotification] {
        guard let reminder = habit.reminderTime, !habit.isArchived, !habit.isPaused else { return [] }
        let comps = calendar.dateComponents([.hour, .minute], from: reminder)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0
        let title = NotificationCopy.habitReminderTitle(tone: tone, habitName: habit.name)
        let body = NotificationCopy.habitReminderBody(tone: tone, habitName: habit.name)
        let weekdays = scheduledCalendarWeekdays(isScheduled: habit.isScheduled,
                                                 calendar: calendar, reference: reference)
        guard !weekdays.isEmpty else { return [] }

        // Scheduled every day → one repeating daily trigger (no weekday component).
        if weekdays.count == 7 {
            return [ScheduledNotification(identifier: HabitNotificationID.identifier(for: habit.id),
                                          title: title, body: body, hour: hour, minute: minute)]
        }

        // Otherwise one repeating trigger per scheduled weekday.
        return weekdays.map { weekday in
            ScheduledNotification(
                identifier: HabitNotificationID.identifier(for: habit.id, weekday: weekday),
                title: title, body: body, weekday: weekday, hour: hour, minute: minute
            )
        }
    }
}
