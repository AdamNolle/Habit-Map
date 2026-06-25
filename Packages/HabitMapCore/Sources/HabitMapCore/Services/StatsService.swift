import Foundation
import SwiftData

@MainActor
public final class StatsService {
    public init() {}

    /// Precompute each habit's `activeSince` floor once so the per-day loops below don't
    /// rescan completions (O(completions)) for every day they evaluate.
    private func activeFloors(_ habits: [Habit]) -> [PersistentIdentifier: Date] {
        Dictionary(uniqueKeysWithValues: habits.map { ($0.persistentModelID, $0.activeSince) })
    }

    /// A day is "complete" for the scope when every scheduled habit that was already active
    /// on that date hit progressFraction >= 1.0. A single call computes floors inline (cheap).
    public func isComplete(on date: Date, habits: [Habit]) -> Bool {
        isComplete(on: date, habits: habits, floors: activeFloors(habits))
    }

    /// Floored completion check used by both the public method and the streak/consistency
    /// loops. `floors` is precomputed by the caller to avoid per-day completion scans.
    private func isComplete(on date: Date, habits: [Habit], floors: [PersistentIdentifier: Date]) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let scheduled = habits.filter {
            $0.isScheduled(date) && day >= (floors[$0.persistentModelID] ?? .distantPast)
        }
        guard !scheduled.isEmpty else { return false }
        return scheduled.allSatisfy { $0.progressFraction(on: date) >= 1.0 }
    }

    /// Average progress across scope on a date (0..1). Used to color combined heatmap cells.
    public func averageProgress(on date: Date, habits: [Habit]) -> Double {
        let scheduled = habits.filter { $0.isScheduled(date) }
        guard !scheduled.isEmpty else { return 0 }
        return scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
    }

    /// Current streak: consecutive complete days going backwards from today.
    public func currentStreak(habits: [Habit], asOf: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let floors = activeFloors(habits)
        var streak = 0
        if isComplete(on: today, habits: habits, floors: floors) { streak += 1 }
        var offset = 1
        while offset < 365 * 2 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            let scheduled = habits.contains {
                $0.isScheduled(day) && day >= (floors[$0.persistentModelID] ?? .distantPast)
            }
            if !scheduled { offset += 1; continue }
            if isComplete(on: day, habits: habits, floors: floors) {
                streak += 1
            } else {
                break
            }
            offset += 1
        }
        return streak
    }

    /// Best (longest-ever) streak across the habits' completion history (last 2 years).
    public func bestStreak(habits: [Habit], asOf: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let floors = activeFloors(habits)
        var best = 0
        var current = 0
        for offset in (0..<730).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let scheduled = habits.contains {
                $0.isScheduled(day) && day >= (floors[$0.persistentModelID] ?? .distantPast)
            }
            if !scheduled { continue }
            if isComplete(on: day, habits: habits, floors: floors) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    /// Per-day completion values for the last `window` days, oldest→newest. `nil` marks a day with
    /// no scheduled+active habit (before a habit's `activeSince`, or simply unscheduled) so callers
    /// render it as a gap rather than a miss; otherwise 1.0 (complete) or 0.0 (scheduled but missed).
    /// Mirrors `consistency(_:)`'s `activeSince` floor so the series never contradicts the headline %.
    public func consistencySeries(habits: [Habit], window: Int = 30, asOf: Date = Date()) -> [Double?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let floors = activeFloors(habits)
        return (0..<window).reversed().map { offset -> Double? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let scheduled = habits.filter {
                $0.isScheduled(day) && day >= (floors[$0.persistentModelID] ?? .distantPast)
            }
            guard !scheduled.isEmpty else { return nil }
            return isComplete(on: day, habits: habits, floors: floors) ? 1.0 : 0.0
        }
    }

    /// 30-day consistency: complete days / scheduled days in the window.
    public func consistency(habits: [Habit], window: Int = 30, asOf: Date = Date()) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let floors = activeFloors(habits)
        var expected = 0
        var achieved = 0
        for offset in 0..<window {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let scheduled = habits.contains {
                $0.isScheduled(day) && day >= (floors[$0.persistentModelID] ?? .distantPast)
            }
            if !scheduled { continue }
            expected += 1
            if isComplete(on: day, habits: habits, floors: floors) { achieved += 1 }
        }
        guard expected > 0 else { return 1.0 }
        return Double(achieved) / Double(expected)
    }
}
