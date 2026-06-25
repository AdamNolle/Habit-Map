import SwiftUI
import SwiftData
import HabitMapCore
import BackgroundTasks
import UserNotifications
import WidgetKit

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
        guard let settings = try? repository.userSettings() else { return }
        let activeHabits = ((try? repository.fetchPages()) ?? [])
            .flatMap { ($0.habits ?? []) }
            .filter { !$0.isArchived && !$0.isPaused }

        var auth = await scheduler.authState()
        // Bug #4: request authorization the first time a reminder is actually
        // enabled — not only when the Setup tab happens to be opened. The
        // `.undetermined` guard means we ask at most once.
        if auth == .undetermined && remindersEnabled(settings: settings, habits: activeHabits) {
            _ = try? await scheduler.requestAuthorization()
            auth = await scheduler.authState()
        }
        guard auth == .authorized else { return }
        await scheduler.cancelAll()

        if let time = settings.dailyReminderTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            // Bug #3: a repeating notification can't know the live count, so use
            // generic copy rather than a stale baked-in number.
            let body = NotificationCopy.dailyReminderBody(tone: settings.notificationTone)
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
                weekday: 1,
                hour: 20, minute: 0
            ))
        }

        for habit in activeHabits {
            await scheduleHabit(habit, settings: settings)
        }
    }

    private func remindersEnabled(settings: UserSettings, habits: [Habit]) -> Bool {
        if settings.dailyReminderTime != nil { return true }
        if settings.weeklyReflectionEnabled { return true }
        return habits.contains { $0.reminderTime != nil }
    }

    func requestPermissionIfNeeded() async {
        let state = await scheduler.authState()
        if state == .undetermined {
            _ = try? await scheduler.requestAuthorization()
            await reschedule()
        }
    }

    func scheduleHabit(_ habit: Habit, settings: UserSettings? = nil) async {
        // Always clear the habit's prior triggers (daily + every weekday variant)
        // first, so a schedule change can't leave stale reminders behind (bug #1).
        await cancelHabit(habit)
        let auth = await scheduler.authState()
        guard auth == .authorized else { return }
        guard habit.reminderTime != nil, !habit.isArchived, !habit.isPaused else { return }
        let resolvedSettings = settings ?? (try? repository.userSettings())
        let tone = resolvedSettings?.notificationTone ?? .gentle
        // Bug #1: a non-everyday habit gets one trigger per scheduled weekday so it
        // no longer fires on rest days. The weekday set is derived in the core layer.
        for notification in HabitReminderPlanner.notifications(for: habit, tone: tone) {
            try? await scheduler.schedule(notification)
        }
    }

    func cancelHabit(_ habit: Habit) async {
        for id in HabitNotificationID.allIdentifiers(for: habit.id) {
            await scheduler.cancel(identifier: id)
        }
    }

    private func handleHabitChange(habit: Habit, change: HabitChange) async {
        // Bug #2: a single coherent reschedule per change. `reschedule()` already
        // cancels and rebuilds every habit's triggers, so the previous extra
        // per-habit schedule/cancel here did the work twice.
        await reschedule()
        // Bug #6: a structural habit change alters what the Today widget shows.
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func habitIdentifier(for id: UUID) -> String {
        HabitNotificationID.identifier(for: id)
    }

    public static func parseHabitID(from identifier: String) -> UUID? {
        HabitNotificationID.parse(identifier)
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
        var userInfo: [AnyHashable: Any] = ["identifier": identifier]
        if let habitID = HabitNotificationID.parse(identifier) {
            userInfo["habitID"] = habitID
        }
        NotificationCenter.default.post(name: .habitMapNotificationTapped,
                                        object: nil,
                                        userInfo: userInfo)
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
    @StateObject private var haptics: Haptics

    init() {
        do {
            // UI tests run against a clean in-memory store: deterministic, and
            // immune to hosted-CI simulators where the on-disk store dir can be
            // missing/read-only (CoreData errno 2/30).
            let isUITesting = ProcessInfo.processInfo.arguments.contains("-uitesting")
            let container = try PersistenceController.makeContainer(
                inMemory: isUITesting,
                enableCloudKit: false,
                appGroupID: isUITesting ? nil : PersistenceController.appGroupID
            )
            self.container = container
            let repo = HabitRepository(context: container.mainContext)
            let provider: HealthKitProviding = HealthKitService()
            let notifScheduler: NotificationScheduling = NotificationScheduler()
            let hapticsEnabled = (try? repo.userSettings())?.hapticsEnabled ?? true
            _repo = StateObject(wrappedValue: repo)
            _sync = StateObject(wrappedValue: HealthSyncService(provider: provider, repository: repo))
            _notifications = StateObject(wrappedValue:
                NotificationCoordinator(scheduler: notifScheduler, repository: repo))
            _haptics = StateObject(wrappedValue: Haptics(isEnabled: hapticsEnabled))
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
                .environmentObject(haptics)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch { }
                    await sync.syncToday()
                    await notifications.reschedule()
                    // Bug #6: reflect any freshly-synced health data in the widget.
                    WidgetCenter.shared.reloadAllTimelines()
                    // Bug #5: bootstrap the first background-refresh request at launch;
                    // BG tasks are one-shot, so the handler re-submits the next one.
                    BackgroundRefresh.schedule()
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await sync.syncToday()
            // Bug #5: an app-refresh task fires once — re-submit to keep the chain alive.
            BackgroundRefresh.schedule()
        }
    }
}

/// Owns the single background health-refresh request. iOS keeps one pending request
/// per identifier, so re-submitting simply replaces it — that is the de-dup guard.
enum BackgroundRefresh {
    static let identifier = "com.adam.habitmap.health-refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: HealthSyncService
    @EnvironmentObject private var notifications: NotificationCoordinator
    @EnvironmentObject private var haptics: Haptics
    @Query private var settingsArray: [UserSettings]
    @State private var activeTab: HabitMapTab = .today

    private var preferredScheme: ColorScheme? {
        switch settingsArray.first?.displayMode {
        case .dark: return .dark
        case .light: return .light
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $activeTab) {
            TodayView()
                .tag(HabitMapTab.today)
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }

            MapView()
                .tag(HabitMapTab.map)
                .tabItem {
                    Label("Map", systemImage: "square.grid.3x3.fill")
                }

            InsightsView()
                .tag(HabitMapTab.stats)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tag(HabitMapTab.setup)
                .tabItem {
                    Label("Setup", systemImage: "gearshape.fill")
                }
        }
        .tint(DesignTokens.Accent.classicGreen)
        .preferredColorScheme(preferredScheme)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await sync.syncToday() }
            case .background:
                // Bug #6: the user may have logged habits this session — refresh the
                // widget now (habit-completion writes don't go through onHabitChanged).
                WidgetCenter.shared.reloadAllTimelines()
                // Bug #5: ensure a background refresh is queued for the next window.
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .onChange(of: activeTab) { _, new in
            haptics.tabChange()
            if new == .setup {
                Task { await notifications.requestPermissionIfNeeded() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitMapNotificationTapped)) { _ in
            activeTab = .today
        }
    }
}
