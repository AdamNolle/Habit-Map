import Foundation

@MainActor
public final class StatsService {
    public init() {}

    /// A day is "complete" for the scope when every scheduled habit hit progressFraction >= 1.0 on that date.
    public func isComplete(on date: Date, habits: [Habit]) -> Bool {
        let scheduled = habits.filter { $0.isScheduled(date) }
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
        var streak = 0
        if isComplete(on: today, habits: habits) { streak += 1 }
        var offset = 1
        while offset < 365 * 2 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            let scheduled = habits.contains(where: { $0.isScheduled(day) })
            if !scheduled { offset += 1; continue }
            if isComplete(on: day, habits: habits) {
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
        var best = 0
        var current = 0
        for offset in (0..<730).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let scheduled = habits.contains(where: { $0.isScheduled(day) })
            if !scheduled { continue }
            if isComplete(on: day, habits: habits) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    /// Per-day binary completion values (1.0 = complete, 0.0 = incomplete/no data) for the last
    /// `window` days. Useful for driving sparklines and pulse charts.
    public func consistencySeries(habits: [Habit], window: Int = 30, asOf: Date = Date()) -> [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        return (0..<window).reversed().map { offset -> Double in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            let scheduled = habits.filter { $0.isScheduled(day) }
            guard !scheduled.isEmpty else { return 0 }
            return isComplete(on: day, habits: habits) ? 1.0 : 0.0
        }
    }

    /// 30-day consistency: complete days / scheduled days in the window.
    public func consistency(habits: [Habit], window: Int = 30, asOf: Date = Date()) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var expected = 0
        var achieved = 0
        for offset in 0..<window {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let scheduled = habits.contains(where: { $0.isScheduled(day) })
            if !scheduled { continue }
            expected += 1
            if isComplete(on: day, habits: habits) { achieved += 1 }
        }
        guard expected > 0 else { return 1.0 }
        return Double(achieved) / Double(expected)
    }
}
