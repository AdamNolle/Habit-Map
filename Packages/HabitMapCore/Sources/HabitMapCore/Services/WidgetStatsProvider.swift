import Foundation

/// Immutable data a Today widget renders. `Codable`/`Sendable` so it can cross
/// the widget timeline boundary; computed in the app's shared store and read by
/// the extension.
public struct WidgetSnapshot: Sendable, Equatable, Codable {
    public let consistencyPct: Int   // 0…100, 30-day window
    public let currentStreak: Int
    public let todayDone: Int
    public let todayTotal: Int
    public let accentHex: String

    public init(consistencyPct: Int, currentStreak: Int,
                todayDone: Int, todayTotal: Int, accentHex: String) {
        self.consistencyPct = consistencyPct
        self.currentStreak = currentStreak
        self.todayDone = todayDone
        self.todayTotal = todayTotal
        self.accentHex = accentHex
    }

    /// Sample data for the widget gallery / previews.
    public static let placeholder = WidgetSnapshot(
        consistencyPct: 72, currentStreak: 5, todayDone: 3, todayTotal: 4, accentHex: "#2BFF5F"
    )

    public var todayComplete: Bool { todayTotal > 0 && todayDone >= todayTotal }

    public var todayFraction: Double {
        guard todayTotal > 0 else { return 0 }
        return min(Double(todayDone) / Double(todayTotal), 1.0)
    }
}

/// Reduces the user's habits to a `WidgetSnapshot`. Pure aggregation over the
/// existing `StatsService`, kept in the package so it's unit-testable without a
/// widget host.
public enum WidgetStatsProvider {
    @MainActor
    public static func snapshot(habits: [Habit],
                                accentHex: String = "#2BFF5F",
                                asOf: Date = Date()) -> WidgetSnapshot {
        let stats = StatsService()
        let active = habits.filter { !$0.isArchived && !$0.isPaused }
        let scheduledToday = active.filter { $0.isScheduled(asOf) }
        let doneToday = scheduledToday.filter { $0.progressFraction(on: asOf) >= 1.0 }.count
        let pct = Int((stats.consistency(habits: active, window: 30, asOf: asOf) * 100).rounded())
        return WidgetSnapshot(
            consistencyPct: pct,
            currentStreak: stats.currentStreak(habits: active, asOf: asOf),
            todayDone: doneToday,
            todayTotal: scheduledToday.count,
            accentHex: accentHex
        )
    }
}
