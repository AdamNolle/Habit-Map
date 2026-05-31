import Foundation
import SwiftData

public enum PersistenceController {
    public static let cloudKitContainerID = "iCloud.com.adam.habitmap"

    /// Shared App Group — lets the widget extension read the same SwiftData store.
    public static let appGroupID = "group.com.adam.habitmap"

    public static func makeContainer(inMemory: Bool = false,
                                     enableCloudKit: Bool = true,
                                     appGroupID: String? = nil) throws -> ModelContainer {
        let schema = Schema([
            HabitPage.self,
            Habit.self,
            HabitCompletion.self,
            UserSettings.self
        ])

        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }

        // Prefer a shared App Group store so the widget reads the same data. Only
        // when the group container actually resolves (provisioned device / sim) —
        // otherwise fall through to the app-local store so launch never fails on
        // an unsigned build.
        if let appGroupID,
           FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
            let groupConfig = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: enableCloudKit ? .private(cloudKitContainerID) : .none
            )
            if let container = try? ModelContainer(for: schema, configurations: [groupConfig]) {
                return container
            }
        }

        let config: ModelConfiguration = enableCloudKit
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                 cloudKitDatabase: .private(cloudKitContainerID))
            : ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func seedIfNeeded(_ context: ModelContext) throws {
        let pageCount = try context.fetchCount(FetchDescriptor<HabitPage>())
        guard pageCount == 0 else { return }
        try SeedData.installDemo(into: context)
    }
}
