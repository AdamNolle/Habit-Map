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

    /// Per-weekday reminder identifier. A habit that isn't scheduled every day
    /// schedules one trigger per weekday (1=Sunday…7=Saturday), each under a distinct
    /// identifier so the notification center doesn't collapse them into one.
    public static func identifier(for id: UUID, weekday: Int) -> String {
        "\(prefix)\(id.uuidString).wd\(weekday)"
    }

    /// Every identifier a single habit may schedule under: the everyday base trigger
    /// plus all seven per-weekday variants. Used to fully clear a habit's pending
    /// reminders regardless of which schedule it currently uses.
    public static func allIdentifiers(for id: UUID) -> [String] {
        [identifier(for: id)] + (1...7).map { identifier(for: id, weekday: $0) }
    }

    public static func parse(_ identifier: String) -> UUID? {
        guard identifier.hasPrefix(prefix) else { return nil }
        let remainder = identifier.dropFirst(prefix.count)
        // A per-weekday identifier appends ".wd<n>"; a UUID string contains no ".",
        // so the UUID is everything up to the first dot (or the whole remainder).
        let uuidPart = remainder.prefix { $0 != "." }
        return UUID(uuidString: String(uuidPart))
    }

    /// The id of the (first) page whose habits include `habitID`, if any.
    public static func pageID(forHabit habitID: UUID, in pages: [HabitPage]) -> UUID? {
        for page in pages where (page.habits ?? []).contains(where: { $0.id == habitID }) {
            return page.id
        }
        return nil
    }
}
