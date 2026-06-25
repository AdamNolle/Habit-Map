import SwiftUI

public struct MasterHeatmapCard: View {
    let page: HabitPage
    let days: Int

    private let title: String
    private let cells: [Cell]

    private struct Cell: Identifiable {
        let id: Int
        let level: CellLevel
        let isToday: Bool
    }

    public init(page: HabitPage, days: Int = 28) {
        self.page = page
        self.days = days
        self.title = "\(days) days · \(page.name.titleCased)"

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = Date()
        let active = (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }

        // Build a per-habit completion lookup ONCE (keyed by start-of-day) so each of
        // the `days` cells resolves a completion in O(1) instead of re-scanning every
        // habit's completion list. Keeps the FIRST completion per day to match
        // `Habit.completion(on:)`'s `.first` semantics, so CellLevel output is identical.
        var lookup: [UUID: [Date: HabitCompletion]] = [:]
        for habit in active {
            var byDay: [Date: HabitCompletion] = [:]
            for completion in (habit.completions ?? []) {
                let day = cal.startOfDay(for: completion.date)
                if byDay[day] == nil { byDay[day] = completion }
            }
            lookup[habit.id] = byDay
        }

        self.cells = (0..<days).map { offset in
            let dayOffset = days - 1 - offset
            let date = cal.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            return Cell(id: offset,
                        level: Self.combinedLevel(on: date, active: active, lookup: lookup, now: now, cal: cal),
                        isToday: cal.isDate(date, inSameDayAs: today))
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                PageMark(accent: page.accentColor, size: 18)
                Text(title)
                    .font(.custom(FontFamily.mono, size: 10))
                    .fontWeight(.semibold)
                    .tracking(10 * 0.14)
                    .foregroundColor(DesignTokens.Surface.mutedText)
                    .textCase(.uppercase)
            }
            HStack(spacing: 2) {
                ForEach(cells) { cell in
                    HabitCell(level: cell.level,
                              accent: page.accentColor,
                              isToday: cell.isToday,
                              size: 10,
                              radius: 2)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 1)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private static func combinedLevel(on date: Date,
                                      active: [Habit],
                                      lookup: [UUID: [Date: HabitCompletion]],
                                      now: Date,
                                      cal: Calendar) -> CellLevel {
        guard !active.isEmpty else { return .empty }
        if date > now { return .future }
        let scheduled = active.filter { $0.isScheduled(date) }
        guard !scheduled.isEmpty else { return .rest }
        let day = cal.startOfDay(for: date)
        let avg = scheduled
            .map { progressFraction(for: $0, completion: lookup[$0.id]?[day]) }
            .reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }

    /// Mirrors `Habit.progressFraction(on:)` but reads a precomputed completion instead
    /// of re-scanning the habit's completion list. Must stay byte-identical to that
    /// method so the rendered CellLevel (and snapshots) are unchanged.
    private static func progressFraction(for habit: Habit, completion: HabitCompletion?) -> Double {
        switch habit.type {
        case .manualOnce:
            return (completion?.reps ?? 0) >= 1 ? 1.0 : 0.0
        case .manualMultiple:
            let reps = completion?.reps ?? 0
            return min(Double(reps) / Double(max(habit.targetReps, 1)), 1.0)
        case .autoHealth:
            let reps = completion?.reps ?? 0
            let goal = habit.healthGoal ?? Double(max(habit.targetReps, 1))
            guard goal > 0 else { return reps > 0 ? 1.0 : 0.0 }
            return min(Double(reps) / goal, 1.0)
        case .inverse:
            return (completion?.slipped ?? false) ? 0.0 : 1.0
        }
    }
}
