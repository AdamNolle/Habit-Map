import Foundation

@MainActor
public final class SlipFeatureExtractor {
    private let stats = StatsService()
    private let insights = InsightsEngine()
    private let risk = RiskForecastEngine()

    public init() {}

    public func extract(habits: [Habit], windowDays: Int = 30, asOf: Date = Date()) -> SlipFeatures {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let activeHabits = habits.filter { !$0.isArchived && !$0.isPaused }
        guard !activeHabits.isEmpty else { return .empty }

        // Totals
        var scheduled = 0
        var completed = 0
        for offset in 0..<windowDays {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            for habit in activeHabits where habit.isScheduled(day) {
                scheduled += 1
                if habit.progressFraction(on: day) >= 1.0 { completed += 1 }
            }
        }
        let consistency = scheduled > 0 ? Double(completed) / Double(scheduled) : 0

        // Per-weekday completion (Mon=0 ... Sun=6)
        var weekday: [(done: Int, total: Int)] = Array(repeating: (0, 0), count: 7)
        for offset in 0..<windowDays {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let wd = (cal.component(.weekday, from: day) + 5) % 7
            for habit in activeHabits where habit.isScheduled(day) {
                weekday[wd].total += 1
                if habit.progressFraction(on: day) >= 1.0 {
                    weekday[wd].done += 1
                }
            }
        }
        let weekdayCompletion = weekday.map { $0.total > 0 ? Double($0.done) / Double($0.total) : 0 }

        // Per-habit features
        let perHabit: [HabitFeatures] = activeHabits.map { habit in
            let c30 = stats.consistency(habits: [habit], window: windowDays, asOf: asOf)
            // Best / worst weekday for THIS habit
            var perWeekday: [(done: Int, total: Int)] = Array(repeating: (0, 0), count: 7)
            for offset in 0..<windowDays {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7
                perWeekday[wd].total += 1
                if habit.progressFraction(on: day) >= 1.0 {
                    perWeekday[wd].done += 1
                }
            }
            let rates: [(wd: Int, rate: Double, total: Int)] = perWeekday.enumerated().compactMap { idx, e in
                guard e.total >= 2 else { return nil }
                return (idx, Double(e.done) / Double(e.total), e.total)
            }
            let best = rates.max(by: { $0.rate < $1.rate })?.wd
            let worst = rates.min(by: { $0.rate < $1.rate })?.wd

            // Days since last log
            let completions = (habit.completions ?? [])
                .filter { ($0.reps > 0) || ($0.slipped) }
                .sorted { $0.date > $1.date }
            let daysSince = completions.first.map {
                cal.dateComponents([.day], from: $0.date, to: today).day ?? 0
            } ?? windowDays

            return HabitFeatures(
                id: habit.id, name: habit.name, typeRaw: habit.typeRaw,
                consistency30d: c30,
                bestWeekday: best, worstWeekday: worst,
                daysSinceLastLog: daysSince
            )
        }

        // Risk forecast → top slip windows
        let forecast = risk.forecast(habits: activeHabits, asOf: asOf)
        let topSlipWindows = forecast.topRisks.prefix(3).map { window in
            SlipWindow(
                weekday: window.weekday,
                bucketHour: Self.hourForBucket(window.bucket),
                skipRate: Self.skipRateForLevel(window.level),
                attempts: window.attempts
            )
        }

        // Idle habits
        let idleNames = perHabit
            .filter { $0.daysSinceLastLog >= 7 }
            .sorted { $0.daysSinceLastLog > $1.daysSinceLastLog }
            .map(\.name)

        // Strong pairs from InsightsEngine.stackingSuggestions
        let pairs: [HabitPair] = insights.stackingSuggestions(habits: activeHabits, asOf: asOf)
            .compactMap { insight in
                // The insight body is "X and Y co-occur N% of the time. Pair them..."
                // Parse names + rate.
                let body = insight.body
                guard let pctRange = body.range(of: #"\d+%"#, options: .regularExpression),
                      let rate = Int(body[pctRange].dropLast()) else { return nil }
                // primaryHabitName is `a`; we need `b` from the body text.
                guard let primary = insight.primaryHabitName else { return nil }
                let parts = body
                    .replacingOccurrences(of: " co-occur", with: "|")
                    .split(separator: "|", maxSplits: 1, omittingEmptySubsequences: true)
                guard let leadingPart = parts.first else { return nil }
                let nameTokens = leadingPart.components(separatedBy: " and ")
                guard nameTokens.count == 2 else { return nil }
                let other = nameTokens[1].trimmingCharacters(in: .whitespaces)
                return HabitPair(a: primary, b: other, coOccurrenceRate: Double(rate) / 100.0)
            }

        // Recovery time: average days from a missed scheduled day to the next completed-scheduled day.
        var recoveryGaps: [Int] = []
        for habit in activeHabits {
            var lastMiss: Date?
            for offset in (0..<windowDays).reversed() {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let done = habit.progressFraction(on: day) >= 1.0
                if !done {
                    if lastMiss == nil { lastMiss = day }
                } else if let miss = lastMiss {
                    let gap = cal.dateComponents([.day], from: miss, to: day).day ?? 0
                    recoveryGaps.append(gap)
                    lastMiss = nil
                }
            }
        }
        let avgRecovery = recoveryGaps.isEmpty ? 0 : Double(recoveryGaps.reduce(0, +)) / Double(recoveryGaps.count)

        // Streak-break signals (human-readable)
        var signals: [String] = []
        if let worst = weekdayCompletion.enumerated().min(by: { $0.element < $1.element }) {
            let best = weekdayCompletion.max() ?? 0.0
            if (best - worst.element) > 0.3 {
                signals.append("\(Self.weekdayName(worst.offset))s")
            }
        }
        if let topWindow = topSlipWindows.first {
            signals.append("\(Self.weekdayName(topWindow.weekday)) at \(Self.formatHour(topWindow.bucketHour))")
        }

        return SlipFeatures(
            windowDays: windowDays,
            totalScheduled: scheduled,
            totalCompleted: completed,
            consistencyPct: consistency,
            perHabit: perHabit,
            weekdayCompletion: weekdayCompletion,
            topSlipWindows: Array(topSlipWindows),
            idleHabits: idleNames,
            strongPairs: pairs,
            recoveryDaysAverage: avgRecovery,
            streakBreakSignals: signals
        )
    }

    // MARK: - Labels

    public nonisolated static func weekdayName(_ wd: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][wd]
    }

    public nonisolated static func hourForBucket(_ bucket: Int) -> Int {
        [6, 9, 12, 15, 18, 21, 0, 3][bucket]
    }

    public nonisolated static func formatHour(_ hour: Int) -> String {
        let h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h12) \(suffix)"
    }

    private nonisolated static func skipRateForLevel(_ level: RiskLevel) -> Double {
        switch level {
        case .danger: return 0.85
        case .warn:   return 0.7
        case .completed1: return 0.55
        case .completed2: return 0.4
        case .completed3: return 0.25
        case .completed4: return 0.1
        case .noData: return 0
        }
    }
}
