import Foundation
import SwiftData

public extension UserSettings {
    /// Fetch the single UserSettings record, creating one with defaults if it doesn't exist.
    @MainActor
    static func fetchOrCreate(in context: ModelContext) throws -> UserSettings {
        let existing = try context.fetch(FetchDescriptor<UserSettings>())
        if let first = existing.first { return first }
        let new = UserSettings()
        context.insert(new)
        try context.save()
        return new
    }
}
