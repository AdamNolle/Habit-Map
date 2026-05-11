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

    var body: some View {
        TodayView()
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await sync.syncToday() }
                }
            }
    }
}
