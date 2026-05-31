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

        // Prefer a shared App Group store so the widget reads the same data — but
        // only when the group container is actually writeable. On an unsigned build
        // (CI / no provisioning) the directory can resolve yet be read-only, which
        // would hand back a broken store; in that case fall through to the
        // app-local store so the app and its tests behave normally.
        if let appGroupID, Self.appGroupIsWriteable(appGroupID) {
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

    /// Resolves the App Group container and confirms it's actually writeable with a
    /// throwaway probe file. Guards against an unsigned build where the path exists
    /// but is read-only.
    private static func appGroupIsWriteable(_ appGroupID: String) -> Bool {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return false
        }
        let probe = url.appendingPathComponent(".habitmap-write-probe-\(UUID().uuidString)")
        do {
            try Data().write(to: probe)
            try? FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    public static func seedIfNeeded(_ context: ModelContext) throws {
        let pageCount = try context.fetchCount(FetchDescriptor<HabitPage>())
        guard pageCount == 0 else { return }
        try SeedData.installDemo(into: context)
    }
}
