import SwiftUI
import SwiftData
import HabitMapCore
import BackgroundTasks
import UserNotifications

@MainActor
final class NotificationCoordinator: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    let scheduler: NotificationScheduling
    let repository: HabitRepository

    init(scheduler: NotificationScheduling, repository: HabitRepository) {
        self.scheduler = scheduler
        self.repository = repository
        super.init()
        UNUserNotificationCenter.current().delegate = self
        repository.onHabitChanged = { [weak self] habit, change in
            Task { @MainActor [weak self] in
                await self?.handleHabitChange(habit: habit, change: change)
            }
        }
    }

    func reschedule() async {
        let auth = await scheduler.authState()
        guard auth == .authorized else { return }
        await scheduler.cancelAll()

        guard let settings = try? repository.userSettings() else { return }

        if let time = settings.dailyReminderTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            let pending = pendingCount()
            let body = NotificationCopy.dailyReminderBody(tone: settings.notificationTone, pendingCount: pending)
            let title = NotificationCopy.dailyReminderTitle(tone: settings.notificationTone)
            try? await scheduler.schedule(ScheduledNotification(
                identifier: "habitmap.daily-reminder",
                title: title, body: body,
                hour: comps.hour ?? 7, minute: comps.minute ?? 0
            ))
        }

        if settings.weeklyReflectionEnabled {
            let title = NotificationCopy.weeklyReflectionTitle(tone: settings.notificationTone)
            let body = NotificationCopy.weeklyReflectionBody(tone: settings.notificationTone)
            try? await scheduler.schedule(ScheduledNotification(
                identifier: "habitmap.weekly-reflection",
                title: title, body: body,
                weekday: 1,        // Sunday
                hour: 20, minute: 0
            ))
        }

        // Per-habit reminders
        let pages = (try? repository.fetchPages()) ?? []
        for page in pages {
            for habit in (page.habits ?? []) {
                guard !habit.isArchived && !habit.isPaused else { continue }
                await scheduleHabit(habit, settings: settings)
            }
        }
    }

    func requestPermissionIfNeeded() async {
        let state = await scheduler.authState()
        if state == .undetermined {
            _ = try? await scheduler.requestAuthorization()
            await reschedule()
        }
    }

    /// Schedule a per-habit reminder if reminderTime is set; cancel otherwise.
    func scheduleHabit(_ habit: Habit, settings: UserSettings? = nil) async {
        let auth = await scheduler.authState()
        guard auth == .authorized else { return }
        let id = Self.habitIdentifier(for: habit.id)
        guard let reminder = habit.reminderTime, !habit.isArchived, !habit.isPaused else {
            await scheduler.cancel(identifier: id)
            return
        }
        let resolvedSettings = settings ?? (try? repository.userSettings())
        let tone = resolvedSettings?.notificationTone ?? .gentle
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminder)
        let title = NotificationCopy.habitReminderTitle(tone: tone, habitName: habit.name)
        let body = NotificationCopy.habitReminderBody(tone: tone, habitName: habit.name)
        try? await scheduler.schedule(ScheduledNotification(
            identifier: id, title: title, body: body,
            hour: comps.hour ?? 9, minute: comps.minute ?? 0
        ))
    }

    func cancelHabit(_ habit: Habit) async {
        await scheduler.cancel(identifier: Self.habitIdentifier(for: habit.id))
    }

    private func handleHabitChange(habit: Habit, change: HabitChange) async {
        switch change {
        case .created, .updated:
            await scheduleHabit(habit)
        case .archived, .deleted:
            await cancelHabit(habit)
        }
        // Recalculate daily-reminder pending count
        await reschedule()
    }

    public static func habitIdentifier(for id: UUID) -> String {
        "habitmap.habit.\(id.uuidString)"
    }

    /// Parses our identifier scheme. Returns a habit UUID for habit-scoped notifications, nil for app-level.
    public static func parseHabitID(from identifier: String) -> UUID? {
        let prefix = "habitmap.habit."
        guard identifier.hasPrefix(prefix) else { return nil }
        let raw = String(identifier.dropFirst(prefix.count))
        return UUID(uuidString: raw)
    }

    private func pendingCount() -> Int {
        let pages = (try? repository.fetchPages()) ?? []
        return pages.flatMap { ($0.habits ?? []) }
            .filter { !$0.isArchived && !$0.isPaused && $0.isScheduled(Date()) }
            .filter { $0.progressFraction(on: Date()) < 1.0 }
            .count
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler:
                                              @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        NotificationCenter.default.post(name: .habitMapNotificationTapped,
                                        object: nil,
                                        userInfo: ["identifier": identifier])
        completionHandler()
    }
}

extension Notification.Name {
    static let habitMapNotificationTapped = Notification.Name("habitMapNotificationTapped")
}

@main
struct HabitMapApp: App {
    let container: ModelContainer
    @StateObject private var repo: HabitRepository
    @StateObject private var sync: HealthSyncService
    @StateObject private var notifications: NotificationCoordinator

    private let healthRefreshIdentifier = "com.adam.habitmap.health-refresh"

    init() {
        do {
            let container = try PersistenceController.makeContainer(enableCloudKit: false)
            self.container = container
            let repo = HabitRepository(context: container.mainContext)
            let provider: HealthKitProviding = HealthKitService()
            let notifScheduler: NotificationScheduling = NotificationScheduler()
            _repo = StateObject(wrappedValue: repo)
            _sync = StateObject(wrappedValue: HealthSyncService(provider: provider, repository: repo))
            _notifications = StateObject(wrappedValue:
                NotificationCoordinator(scheduler: notifScheduler, repository: repo))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(repo)
                .environmentObject(sync)
                .environmentObject(notifications)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch { print("Seed failed: \(error)") }
                    await sync.syncToday()
                    await notifications.reschedule()
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(healthRefreshIdentifier)) {
            await sync.syncToday()
            await scheduleNextRefresh()
        }
    }

    private func scheduleNextRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: healthRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: HealthSyncService
    @EnvironmentObject private var notifications: NotificationCoordinator
    @State private var activeTab: HabitMapTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .today: TodayView()
                case .map:   MapView()
                case .stats: InsightsView()
                case .setup: SettingsView()
                }
            }
            .padding(.bottom, 80)

            TabBar(active: activeTab) { tab in
                activeTab = tab
                if tab == .setup {
                    Task { await notifications.requestPermissionIfNeeded() }
                }
            }
        }
        .background(DesignTokens.Surface.bg)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await sync.syncToday() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitMapNotificationTapped)) { _ in
            activeTab = .today
        }
    }
}
