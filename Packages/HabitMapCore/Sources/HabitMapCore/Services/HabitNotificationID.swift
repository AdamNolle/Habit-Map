import Foundation
import SwiftData

/// Encodes/decodes the per-habit local-notification identifier and resolves which
/// page a habit lives on — used to route a notification tap to the right page.
///
/// Pure value logic in the package so it's unit-testable without the app target.
public enum HabitNotificationID {
    public static let prefix = "habitmap.habit."

    public static func identifier(for id: UUID) -> String {
        prefix + id.uuidString
    }

    public static func parse(_ identifier: String) -> UUID? {
        guard identifier.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(prefix.count)))
    }

    /// The id of the (first) page whose habits include `habitID`, if any.
    public static func pageID(forHabit habitID: UUID, in pages: [HabitPage]) -> UUID? {
        for page in pages where (page.habits ?? []).contains(where: { $0.id == habitID }) {
            return page.id
        }
        return nil
    }
}
