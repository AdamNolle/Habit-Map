import SwiftUI
import SwiftData
import HabitMapCore

@main
struct HabitMapApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try PersistenceController.makeContainer(enableCloudKit: false)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
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
