import Foundation
import SwiftData

public enum PersistenceController {
    public static let cloudKitContainerID = "iCloud.com.adam.habitmap"

    public static func makeContainer(inMemory: Bool = false,
                                     enableCloudKit: Bool = true) throws -> ModelContainer {
        let schema = Schema([
            HabitPage.self,
            Habit.self,
            HabitCompletion.self,
            UserSettings.self
        ])

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if enableCloudKit {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func seedIfNeeded(_ context: ModelContext) throws {
        let pageCount = try context.fetchCount(FetchDescriptor<HabitPage>())
        guard pageCount == 0 else { return }
        try SeedData.installDemo(into: context)
    }
}
