import Foundation

@MainActor
public final class InsightsEngine {
    public init() {}

    public func generate(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        var result: [Insight] = []
        result.append(contentsOf: strongestDayOfWeek(habits: habits, asOf: asOf))
        result.append(contentsOf: idleHabits(habits: habits, asOf: asOf))
        result.append(contentsOf: stackingSuggestions(habits: habits, asOf: asOf))
        result.append(contentsOf: timeOfDaySkipRisk(habits: habits, asOf: asOf))
        return result
    }

    // MARK: - Strongest day-of-week

    public func strongestDayOfWeek(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var insights: [Insight] = []

        for habit in habits where !habit.isArchived && !habit.isPaused {
            var perWeekday: [Int: (attempted: Int, completed: Int)] = [:]
            for offset in 0..<30 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7
                var entry = perWeekday[wd] ?? (0, 0)
                entry.attempted += 1
                if habit.progressFraction(on: day) >= 1.0 { entry.completed += 1 }
                perWeekday[wd] = entry
            }
            let bestWeekday = perWeekday
                .filter { $0.value.attempted >= 4 }
                .max(by: { lhs, rhs in
                    let l = Double(lhs.value.completed) / Double(lhs.value.attempted)
                    let r = Double(rhs.value.completed) / Double(rhs.value.attempted)
                    return l < r
                })
            if let best = bestWeekday {
                let rate = Double(best.value.completed) / Double(best.value.attempted)
                if rate >= 0.8 {
                    let dayName = Self.weekdayName(best.key)
                    insights.append(Insight(
                        kind: .win,
                        title: "STRONG \(dayName.uppercased())S",
                        body: "\(habit.name.capitalized) hits \(Int(rate * 100))% of \(dayName)s — your best day.",
                        primaryHabitID: habit.id,
                        primaryHabitName: habit.name,
                        primaryAccentHex: habit.accentHex
                    ))
                }
            }
        }
        return insights
    }

    // MARK: - Idle habit

    public func idleHabits(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var insights: [Insight] = []

        // Inverse habits (avoid-a-bad-habit) succeed precisely by NOT being logged,
        // so a quiet stretch is a win — never an "idle, want to pause?" nudge.
        for habit in habits where !habit.isArchived && !habit.isPaused && habit.type != .inverse {
            let completions = (habit.completions ?? [])
                .filter { ($0.reps > 0) || ($0.slipped) }
                .sorted { $0.date > $1.date }
            guard let mostRecent = completions.first else { continue }

            let daysSince = cal.dateComponents([.day], from: mostRecent.date, to: today).day ?? 0
            guard daysSince >= 7 else { continue }

            let priorWindow = completions.filter { c in
                let off = cal.dateComponents([.day], from: c.date, to: today).day ?? 0
                return off >= 7 && off <= 37
            }
            guard !priorWindow.isEmpty else { continue }

            let body: String
            if daysSince >= 14 {
                body = "\(habit.name.capitalized) — \(daysSince) days since last log. Want to pause it?"
            } else {
                body = "\(habit.name.capitalized) — \(daysSince) days since last log."
            }
            insights.append(Insight(
                kind: .risk,
                title: "IDLE",
                body: body,
                primaryHabitID: habit.id,
                primaryHabitName: habit.name,
                primaryAccentHex: habit.accentHex
            ))
        }
        return insights
    }

    // MARK: - Stacking suggestion

    /// Jaccard co-occurrence over the last 30 days. Of the days where either habit was completed,
    /// how often were both completed? Needs >= 4 either-days and >= 70% co-occurrence.
    public func stackingSuggestions(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let active = habits.filter { !$0.isArchived && !$0.isPaused }
        guard active.count >= 2 else { return [] }

        var insights: [Insight] = []
        for i in 0..<active.count {
            for j in (i + 1)..<active.count {
                let a = active[i], b = active[j]
                var both = 0
                var either = 0
                for offset in 0..<30 {
                    guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                    let aDone = a.progressFraction(on: day) >= 1.0
                    let bDone = b.progressFraction(on: day) >= 1.0
                    if aDone || bDone { either += 1 }
                    if aDone && bDone { both += 1 }
                }
                guard either >= 4 else { continue }
                let rate = Double(both) / Double(either)
                if rate >= 0.7 {
                    insights.append(Insight(
                        kind: .suggest,
                        title: "STACK",
                        body: "\(a.name.capitalized) and \(b.name.capitalized) co-occur \(Int(rate * 100))% of the time. Pair them in your routine.",
                        primaryHabitID: a.id,
                        primaryHabitName: a.name,
                        primaryAccentHex: a.accentHex
                    ))
                }
            }
        }
        return insights
    }

    // MARK: - Time-of-day skip risk

    public func timeOfDaySkipRisk(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var insights: [Insight] = []

        for habit in habits where !habit.isArchived && !habit.isPaused {
            let expectedBucket = Self.expectedBucket(for: habit, cal: cal)
            var buckets: [Int: (attempts: Int, skips: Int)] = [:]
            for offset in 1..<30 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7
                let completed = habit.progressFraction(on: day) >= 1.0
                let completion = habit.completion(on: day)
                let bucket: Int
                if completed, let logged = completion?.loggedAt {
                    bucket = Self.bucketIndex(for: logged, cal: cal)
                } else if let expectedBucket {
                    // Skipped (or completed without a timestamp): attribute the day to
                    // the habit's expected time-of-day, not the "overnight" sentinel.
                    bucket = expectedBucket
                } else {
                    continue  // No signal for when this habit belongs — don't fabricate a window.
                }
                let key = wd * 8 + bucket
                var entry = buckets[key] ?? (0, 0)
                entry.attempts += 1
                if !completed { entry.skips += 1 }
                buckets[key] = entry
            }
            let worst = buckets
                .filter { $0.value.attempts >= 4 }
                .max(by: { lhs, rhs in
                    Double(lhs.value.skips) / Double(lhs.value.attempts)
                    < Double(rhs.value.skips) / Double(rhs.value.attempts)
                })
            if let worst {
                let rate = Double(worst.value.skips) / Double(worst.value.attempts)
                if rate >= 0.5 {
                    let wd = worst.key / 8
                    let bucket = worst.key % 8
                    insights.append(Insight(
                        kind: .risk,
                        title: "SLIP WINDOW",
                        body: "\(habit.name.capitalized) tends to slip \(Self.weekdayName(wd))s around \(Self.bucketLabel(bucket)). Want to try it earlier?",
                        primaryHabitID: habit.id,
                        primaryHabitName: habit.name,
                        primaryAccentHex: habit.accentHex
                    ))
                }
            }
        }
        return insights
    }

    // MARK: - Labels

    public static func weekdayName(_ wd: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][wd]
    }

    public static func bucketIndex(for date: Date, cal: Calendar) -> Int {
        let hour = cal.component(.hour, from: date)
        switch hour {
        case 6..<9: return 0
        case 9..<12: return 1
        case 12..<15: return 2
        case 15..<18: return 3
        case 18..<21: return 4
        case 21..<24: return 5
        case 0..<3: return 6
        default: return 7
        }
    }

    /// The time-of-day bucket a *skipped* day should be attributed to — the time the
    /// user intends to (or usually does) perform the habit. Used so that skips don't
    /// all funnel into the "overnight" sentinel bucket.
    ///
    /// - Returns the bucket of `reminderTime` when set; otherwise the habit's modal
    ///   completion bucket (the time it's most often logged) when there's enough
    ///   history; otherwise `nil` so callers can avoid inventing a fake slip window.
    public static func expectedBucket(for habit: Habit, cal: Calendar) -> Int? {
        if let reminder = habit.reminderTime {
            return bucketIndex(for: reminder, cal: cal)
        }
        var counts: [Int: Int] = [:]
        for completion in (habit.completions ?? []) where completion.reps > 0 {
            counts[bucketIndex(for: completion.loggedAt, cal: cal), default: 0] += 1
        }
        guard let modal = counts.max(by: { $0.value < $1.value }), modal.value >= 3 else {
            return nil
        }
        return modal.key
    }

    public static func bucketLabel(_ bucket: Int) -> String {
        ["mornings", "late morning", "early afternoon", "afternoon",
         "evenings", "late evening", "late night", "overnight"][bucket]
    }
}
