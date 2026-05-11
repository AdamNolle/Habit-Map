import SwiftUI
import SwiftData
import HabitMapCore
import BackgroundTasks

@main
struct HabitMapApp: App {
    let container: ModelContainer
    @StateObject private var repo: HabitRepository
    @StateObject private var sync: HealthSyncService

    private let healthRefreshIdentifier = "com.adam.habitmap.health-refresh"

    init() {
        do {
            let container = try PersistenceController.makeContainer(enableCloudKit: false)
            self.container = container
            let repo = HabitRepository(context: container.mainContext)
            let provider: HealthKitProviding = HealthKitService()
            _repo = StateObject(wrappedValue: repo)
            _sync = StateObject(wrappedValue: HealthSyncService(provider: provider, repository: repo))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(repo)
                .environmentObject(sync)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch { print("Seed failed: \(error)") }
                    await sync.syncToday()
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
    @State private var activeTab: HabitMapTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .today: TodayView()
                case .map:   MapView()
                case .stats: ComingSoonView(title: "STATS", plan: "PLAN 05")
                case .setup: ComingSoonView(title: "SETUP", plan: "PLAN 06")
                }
            }
            .padding(.bottom, 80)

            TabBar(active: activeTab) { tab in activeTab = tab }
        }
        .background(DesignTokens.Surface.bg)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await sync.syncToday() }
            }
        }
    }
}
