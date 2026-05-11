import SwiftUI
import SwiftData
import HabitMapCore

@main
struct HabitMapApp: App {
    let container: ModelContainer
    @StateObject private var repo: HabitRepository

    init() {
        do {
            let container = try PersistenceController.makeContainer(enableCloudKit: false)
            self.container = container
            _repo = StateObject(wrappedValue: HabitRepository(context: container.mainContext))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environmentObject(repo)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch {
                        print("Seed failed: \(error)")
                    }
                }
        }
        .modelContainer(container)
    }
}
