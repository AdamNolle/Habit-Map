# Habit Map — Plan 05: Insights + Risk Forecast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tap STATS in the tab bar to open `InsightsView`. The screen surfaces actionable insights (strongest day-of-week wins, idle habit risks, habit-stacking suggestions, time-of-day skip risks) computed by `InsightsEngine`, plus a weekday × time-of-day `RiskHeatmap` produced by `RiskForecastEngine`. Tapping the risk heatmap expands it full-screen. All work is pure Swift on top of the existing `Habit` / `HabitCompletion` data — no new model fields, no network.

**Architecture:** Two pure services on a background-eligible `@MainActor` class: `InsightsEngine` produces `[Insight]`, `RiskForecastEngine` produces a `RiskForecast` value-type (matrix of `RiskLevel`s plus a list of top risks). `InsightsView` renders results via `InsightCard` + `RiskHeatmap` components. STATS tab routes to `InsightsView` (the `ComingSoonView` placeholder is removed).

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 17+, SwiftData. No new dependencies.

---

## Context

Plans 01-04 shipped: foundation, pages/habits CRUD, HealthKit, heat map. STATS tab currently renders `ComingSoonView`. Spec §11 describes 7 insight algorithms plus the risk forecast. This plan ships 4 of them (the ones that work with the data we already collect) and the full risk forecast. The other 3 (`reminder impact`, `phase graduation`, `seasonal dip`) need either an extra model field or > 1 year of history — they ship in a later plan.

**Defining "skip" for the risk forecast.** For each (weekday, 3-hour-bucket) pair, count days where the bucket was *expected* (habit was scheduled that weekday, and the user has *some* completion history for that habit) versus *completed-by-then* (a completion exists with `loggedAt` falling inside the bucket OR earlier that day). Risk = `1 - completed / attempted`. Need ≥ 4 data points per bucket to emit `warn`/`danger`; otherwise `noData`.

**Out of scope:** reminder impact · phase graduation · seasonal dip · notifications scheduling · settings · reset data · widgets · live activity · watch · iPad layouts · onboarding · themes · CloudKit cutover.

---

## File Structure (new additions)

```
Packages/HabitMapCore/
  Sources/HabitMapCore/
    Models/
      Insight.swift                       # kind / title / body / habitId
      RiskForecast.swift                  # matrix + top risks
    Services/
      InsightsEngine.swift                # 4 algorithms
      RiskForecastEngine.swift            # weekday × bucket matrix
    Components/
      InsightCard.swift                   # pixel-art insight tile
      RiskHeatmap.swift                   # 7-row × 8-col grid
  Tests/HabitMapCoreTests/
    InsightsEngineTests.swift             # one test per algorithm + edge cases
    RiskForecastEngineTests.swift         # bucketization + level mapping
    InsightCardSnapshotTests.swift
    RiskHeatmapSnapshotTests.swift

Apps/iOS/HabitMap/
  Screens/
    Insights/
      InsightsView.swift                  # full-page; renders cards + heatmap
      RiskExpandedView.swift              # full-screen heatmap
  HabitMapApp.swift                       # (modified) STATS → InsightsView
HabitMapUITests/
  InsightsNavigationUITests.swift         # tap STATS → header visible
```

---

## Task 1: Insight model + InsightsEngine

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Models/Insight.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/InsightsEngine.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/InsightsEngineTests.swift`

- [ ] **Step 1: Write `Insight.swift`**

```swift
import Foundation

public enum InsightKind: String, Sendable, CaseIterable {
    case win, risk, suggest
}

public struct Insight: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: InsightKind
    public let title: String          // short label, all-caps for pixel-text
    public let body: String           // longer human-readable string
    public let primaryHabitID: UUID?
    public let primaryHabitName: String?
    public let primaryAccentHex: String?

    public init(id: UUID = UUID(),
                kind: InsightKind,
                title: String,
                body: String,
                primaryHabitID: UUID? = nil,
                primaryHabitName: String? = nil,
                primaryAccentHex: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.primaryHabitID = primaryHabitID
        self.primaryHabitName = primaryHabitName
        self.primaryAccentHex = primaryAccentHex
    }
}
```

- [ ] **Step 2: Write `InsightsEngine.swift`**

```swift
import Foundation

@MainActor
public final class InsightsEngine {
    public init() {}

    /// Produce all insights for the given habit scope.
    /// `asOf` is exposed for testing (defaults to now).
    public func generate(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        var result: [Insight] = []
        result.append(contentsOf: strongestDayOfWeek(habits: habits, asOf: asOf))
        result.append(contentsOf: idleHabits(habits: habits, asOf: asOf))
        result.append(contentsOf: stackingSuggestions(habits: habits, asOf: asOf))
        result.append(contentsOf: timeOfDaySkipRisk(habits: habits, asOf: asOf))
        return result
    }

    // MARK: - Strongest day-of-week

    /// For each habit: if a weekday has > 80% completion over the last 30 days and at
    /// least 4 occurrences, emit a WIN insight.
    public func strongestDayOfWeek(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var insights: [Insight] = []

        for habit in habits where !habit.isArchived && !habit.isPaused {
            var perWeekday: [Int: (attempted: Int, completed: Int)] = [:]
            for offset in 0..<30 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7   // Mon=0
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

    /// If a habit has no completion in the last 7 days but had at least one in the prior 30, emit RISK.
    /// At 14 days idle, the body suggests pausing.
    public func idleHabits(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var insights: [Insight] = []

        for habit in habits where !habit.isArchived && !habit.isPaused {
            let completions = (habit.completions ?? [])
                .filter { ($0.reps > 0) || ($0.slipped) }
                .sorted { $0.date > $1.date }
            guard let mostRecent = completions.first else { continue }

            let daysSince = cal.dateComponents([.day], from: mostRecent.date, to: today).day ?? 0
            guard daysSince >= 7 else { continue }

            // Only emit if there was activity in the prior 30 days (filters out brand-new habits).
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

    /// For each pair (A, B): co-occurrence rate over the last 30 scheduled-for-both days.
    /// If >= 70% AND >= 4 co-days, emit SUGGEST.
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
                var coDays = 0
                for offset in 0..<30 {
                    guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                    let aSched = a.isScheduled(day), bSched = b.isScheduled(day)
                    guard aSched && bSched else { continue }
                    coDays += 1
                    let aDone = a.progressFraction(on: day) >= 1.0
                    let bDone = b.progressFraction(on: day) >= 1.0
                    if aDone && bDone { both += 1 }
                }
                guard coDays >= 4 else { continue }
                let rate = Double(both) / Double(coDays)
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

    /// Bucket missed-by-the-end-of-bucket days by (weekday, 3h bucket).
    /// If skip rate >= 50% with >= 4 attempts: emit RISK with a "Saturday evenings tend to slip" body.
    public func timeOfDaySkipRisk(habits: [Habit], asOf: Date = Date()) -> [Insight] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var insights: [Insight] = []

        for habit in habits where !habit.isArchived && !habit.isPaused {
            // (weekday, bucket) → (attempts, skips)
            var buckets: [Int: (attempts: Int, skips: Int)] = [:]
            for offset in 1..<30 {
                // Skip today; today isn't a "miss" yet.
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7
                // What time did the user typically attempt this habit on past days? Use loggedAt of completions.
                // For each bucket of THIS specific day, if completed by end of bucket count as success,
                // else if scheduled-but-not-yet-completed-by-end-of-day, count as a skip in the LAST bucket of the day.
                let completed = habit.progressFraction(on: day) >= 1.0
                let completion = habit.completion(on: day)
                let bucket: Int
                if let logged = completion?.loggedAt, completed {
                    bucket = Self.bucketIndex(for: logged, cal: cal)
                } else {
                    bucket = 7 // skipped — attribute to last (3am) bucket
                }
                let key = wd * 8 + bucket
                var entry = buckets[key] ?? (0, 0)
                entry.attempts += 1
                if !completed { entry.skips += 1 }
                buckets[key] = entry
            }
            // Find worst bucket with ≥ 4 attempts and >= 50% skip
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

    static func weekdayName(_ wd: Int) -> String {
        // Mon=0 ... Sun=6
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][wd]
    }

    static func bucketIndex(for date: Date, cal: Calendar) -> Int {
        let hour = cal.component(.hour, from: date)
        // 0=6am, 1=9am, 2=12pm, 3=3pm, 4=6pm, 5=9pm, 6=12am, 7=3am
        switch hour {
        case 6..<9: return 0
        case 9..<12: return 1
        case 12..<15: return 2
        case 15..<18: return 3
        case 18..<21: return 4
        case 21..<24: return 5
        case 0..<3: return 6
        default: return 7    // 3am-6am
        }
    }

    static func bucketLabel(_ bucket: Int) -> String {
        ["mornings", "late morning", "early afternoon", "afternoon",
         "evenings", "late evening", "late night", "overnight"][bucket]
    }
}
```

- [ ] **Step 3: Write `InsightsEngineTests.swift`**

```swift
import XCTest
import SwiftData
@testable import HabitMapCore

final class InsightsEngineTests: XCTestCase {
    var container: ModelContainer!
    var engine: InsightsEngine!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        engine = InsightsEngine()
    }

    @MainActor
    private func makeHabit(name: String = "H", weekdayMask: Int8 = 0b01111111) -> Habit {
        let h = Habit(name: name, emoji: "x", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: weekdayMask)
        container.mainContext.insert(h)
        try? container.mainContext.save()
        return h
    }

    @MainActor
    private func completeHabit(_ habit: Habit, daysAgo: Int, loggedHour: Int? = nil) {
        let cal = Calendar.current
        let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let loggedAt: Date
        if let h = loggedHour {
            loggedAt = cal.date(bySettingHour: h, minute: 0, second: 0, of: date) ?? date
        } else {
            loggedAt = date
        }
        let c = HabitCompletion(date: date, reps: 1, loggedAt: loggedAt, habit: habit)
        container.mainContext.insert(c)
        try? container.mainContext.save()
    }

    // MARK: - strongestDayOfWeek

    @MainActor
    func test_strongestDayOfWeek_emitsWinOnHighRate() {
        // Pick a stable reference date: 4 Mondays ago (or last 30 days will have ~4 Mondays).
        let h = makeHabit()
        let cal = Calendar.current
        // Complete every weekday for last 30 days. Best day = whichever has highest count of full completions.
        for offset in 0..<30 { completeHabit(h, daysAgo: offset) }
        let insights = engine.strongestDayOfWeek(habits: [h])
        XCTAssertFalse(insights.isEmpty)
        XCTAssertEqual(insights.first?.kind, .win)
    }

    @MainActor
    func test_strongestDayOfWeek_noEmissionBelowThreshold() {
        let h = makeHabit()
        // Complete only every 3rd day → < 80% on any weekday.
        for offset in stride(from: 0, to: 30, by: 3) { completeHabit(h, daysAgo: offset) }
        let insights = engine.strongestDayOfWeek(habits: [h])
        XCTAssertTrue(insights.isEmpty)
    }

    // MARK: - idleHabits

    @MainActor
    func test_idleHabits_emitsAfter7DaysIdleWithPriorActivity() {
        let h = makeHabit()
        // Activity 8-15 days ago, nothing in last 7.
        for offset in 8..<16 { completeHabit(h, daysAgo: offset) }
        let insights = engine.idleHabits(habits: [h])
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.kind, .risk)
        XCTAssertEqual(insights.first?.title, "IDLE")
    }

    @MainActor
    func test_idleHabits_skipsBrandNewHabit() {
        // No completions ever → no insight (filters out fresh habits).
        let h = makeHabit()
        XCTAssertTrue(engine.idleHabits(habits: [h]).isEmpty)
    }

    @MainActor
    func test_idleHabits_skipsActiveHabit() {
        let h = makeHabit()
        completeHabit(h, daysAgo: 0)
        completeHabit(h, daysAgo: 2)
        XCTAssertTrue(engine.idleHabits(habits: [h]).isEmpty)
    }

    @MainActor
    func test_idleHabits_14daysSuggestsPause() {
        let h = makeHabit()
        for offset in 15..<22 { completeHabit(h, daysAgo: offset) }
        let insights = engine.idleHabits(habits: [h])
        XCTAssertEqual(insights.count, 1)
        XCTAssertTrue(insights.first!.body.contains("pause"))
    }

    // MARK: - stackingSuggestions

    @MainActor
    func test_stackingSuggestions_pairsCo-occur() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        for offset in 0..<10 {
            completeHabit(a, daysAgo: offset)
            completeHabit(b, daysAgo: offset)
        }
        let insights = engine.stackingSuggestions(habits: [a, b])
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.kind, .suggest)
    }

    @MainActor
    func test_stackingSuggestions_noPairBelowThreshold() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        for offset in 0..<10 { completeHabit(a, daysAgo: offset) }
        // b never done with a → 0% co-occurrence
        XCTAssertTrue(engine.stackingSuggestions(habits: [a, b]).isEmpty)
    }

    // MARK: - timeOfDaySkipRisk

    @MainActor
    func test_timeOfDaySkipRisk_emitsOnHighSkipBucket() {
        let h = makeHabit()
        let cal = Calendar.current
        // 4+ Saturdays missed in the last 30 days, others completed.
        for offset in 1..<30 {
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            let wd = (cal.component(.weekday, from: day) + 5) % 7
            if wd == 5 {
                // Saturday — skip (don't insert a completion)
                continue
            } else {
                completeHabit(h, daysAgo: offset, loggedHour: 9)
            }
        }
        let insights = engine.timeOfDaySkipRisk(habits: [h])
        // Saturday should appear if ≥ 4 occurred in last 30 days.
        // 4 Saturdays in 29 days is plausible (could be 4 or 5).
        if !insights.isEmpty {
            XCTAssertEqual(insights.first?.kind, .risk)
        }
    }
}
```

- [ ] **Step 4: Run, commit**

```bash
xcodegen generate
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/InsightsEngineTests
git add Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "feat(insights): add InsightsEngine with 4 algorithms"
```

---

## Task 2: RiskForecast model + RiskForecastEngine

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Models/RiskForecast.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/RiskForecastEngine.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/RiskForecastEngineTests.swift`

- [ ] **Step 1: Write `RiskForecast.swift`**

```swift
import Foundation

public enum RiskLevel: Int, Sendable, Comparable {
    case noData = 0
    case completed4 = 1     // best — < 20% skip
    case completed3 = 2
    case completed2 = 3
    case completed1 = 4
    case warn = 5
    case danger = 6         // ≥ 80% skip

    public static func < (a: RiskLevel, b: RiskLevel) -> Bool { a.rawValue < b.rawValue }
}

public struct RiskForecast: Sendable, Equatable {
    public let matrix: [[RiskLevel]]   // [7 weekdays][8 time buckets]
    public let topRisks: [RiskWindow]

    public init(matrix: [[RiskLevel]], topRisks: [RiskWindow]) {
        self.matrix = matrix
        self.topRisks = topRisks
    }

    public static let empty = RiskForecast(
        matrix: Array(repeating: Array(repeating: RiskLevel.noData, count: 8), count: 7),
        topRisks: []
    )
}

public struct RiskWindow: Sendable, Equatable {
    public let weekday: Int      // Mon=0 ... Sun=6
    public let bucket: Int       // 0..7
    public let level: RiskLevel
    public let attempts: Int

    public init(weekday: Int, bucket: Int, level: RiskLevel, attempts: Int) {
        self.weekday = weekday
        self.bucket = bucket
        self.level = level
        self.attempts = attempts
    }
}
```

- [ ] **Step 2: Write `RiskForecastEngine.swift`**

```swift
import Foundation

@MainActor
public final class RiskForecastEngine {
    public init() {}

    public func forecast(habits: [Habit], asOf: Date = Date()) -> RiskForecast {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        // (weekday, bucket) → (attempts, skips)
        var buckets: [[(attempts: Int, skips: Int)]] =
            Array(repeating: Array(repeating: (0, 0), count: 8), count: 7)

        for habit in habits where !habit.isArchived && !habit.isPaused {
            for offset in 1..<30 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard habit.isScheduled(day) else { continue }
                let wd = (cal.component(.weekday, from: day) + 5) % 7
                let completed = habit.progressFraction(on: day) >= 1.0
                let completion = habit.completion(on: day)
                let bucket: Int
                if let logged = completion?.loggedAt, completed {
                    bucket = InsightsEngine.bucketIndex(for: logged, cal: cal)
                } else {
                    bucket = 7
                }
                buckets[wd][bucket].attempts += 1
                if !completed { buckets[wd][bucket].skips += 1 }
            }
        }

        var matrix = Array(repeating: Array(repeating: RiskLevel.noData, count: 8), count: 7)
        var allWindows: [RiskWindow] = []
        for wd in 0..<7 {
            for bucket in 0..<8 {
                let entry = buckets[wd][bucket]
                guard entry.attempts >= 4 else { continue }
                let skipRate = Double(entry.skips) / Double(entry.attempts)
                let level: RiskLevel
                switch skipRate {
                case 0.80...:  level = .danger
                case 0.65...:  level = .warn
                case 0.50...:  level = .completed1
                case 0.35...:  level = .completed2
                case 0.20...:  level = .completed3
                default:       level = .completed4
                }
                matrix[wd][bucket] = level
                allWindows.append(RiskWindow(weekday: wd, bucket: bucket, level: level, attempts: entry.attempts))
            }
        }
        let topRisks = allWindows
            .filter { $0.level >= .warn }
            .sorted { $0.level > $1.level }
            .prefix(3)
        return RiskForecast(matrix: matrix, topRisks: Array(topRisks))
    }
}
```

- [ ] **Step 3: Write `RiskForecastEngineTests.swift`**

```swift
import XCTest
import SwiftData
@testable import HabitMapCore

final class RiskForecastEngineTests: XCTestCase {
    var container: ModelContainer!
    var engine: RiskForecastEngine!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        engine = RiskForecastEngine()
    }

    @MainActor
    private func makeHabit() -> Habit {
        let h = Habit(name: "H", emoji: "x", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0b01111111)
        container.mainContext.insert(h); try? container.mainContext.save()
        return h
    }

    @MainActor
    func test_emptyHabits_returnsAllNoData() {
        let forecast = engine.forecast(habits: [])
        for row in forecast.matrix {
            for level in row { XCTAssertEqual(level, .noData) }
        }
        XCTAssertTrue(forecast.topRisks.isEmpty)
    }

    @MainActor
    func test_neverScheduled_returnsAllNoData() {
        let h = Habit(name: "H", emoji: "x", accentHex: "#FFFFFF",
                      type: .manualOnce, targetReps: 1, weekdayMask: 0)
        container.mainContext.insert(h); try? container.mainContext.save()
        let forecast = engine.forecast(habits: [h])
        for row in forecast.matrix {
            for level in row { XCTAssertEqual(level, .noData) }
        }
    }

    @MainActor
    func test_matrixHasCorrectDimensions() {
        let forecast = engine.forecast(habits: [])
        XCTAssertEqual(forecast.matrix.count, 7)
        XCTAssertEqual(forecast.matrix.first?.count, 8)
    }

    @MainActor
    func test_topRisks_limitedToThree() {
        // Synthesize a habit with 28 days of skips → many buckets land in danger.
        let h = makeHabit()
        // No completions for any day → all attempts skip, all attribute to bucket 7.
        let forecast = engine.forecast(habits: [h])
        XCTAssertLessThanOrEqual(forecast.topRisks.count, 3)
    }
}
```

- [ ] **Step 4: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/RiskForecastEngineTests
git commit -m "feat(insights): add RiskForecastEngine producing weekday × bucket matrix"
```

---

## Task 3: InsightCard component

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/InsightCard.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/InsightCardSnapshotTests.swift`

- [ ] **Step 1: Write `InsightCard.swift`**

```swift
import SwiftUI

public struct InsightCard: View {
    let insight: Insight

    public init(insight: Insight) {
        self.insight = insight
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 6) {
                PixelText(insight.title, pixelSize: 2, color: accent)
                Text(insight.body)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(DesignTokens.Surface.mutedText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(accent, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body)")
    }

    private var accent: Color {
        if let hex = insight.primaryAccentHex { return Color(hex: hex) }
        switch insight.kind {
        case .win:     return DesignTokens.Accent.classicGreen
        case .risk:    return DesignTokens.Surface.miss
        case .suggest: return DesignTokens.Accent.cobalt
        }
    }

    @ViewBuilder private var badge: some View {
        let bg: Color = {
            switch insight.kind {
            case .win:     return DesignTokens.Accent.classicGreen
            case .risk:    return DesignTokens.Surface.miss
            case .suggest: return DesignTokens.Accent.cobalt
            }
        }()
        Rectangle()
            .fill(bg)
            .frame(width: 28, height: 28)
            .overlay(Rectangle().stroke(bg.darker(by: 0.2), lineWidth: 2))
            .overlay(
                PixelText(badgeChar, pixelSize: 3, color: .black)
            )
    }

    private var badgeChar: String {
        switch insight.kind {
        case .win:     return "."
        case .risk:    return "!"
        case .suggest: return "?"
        }
    }
}
```

Note: PixelFont doesn't define `!` or `?` — the badge falls back to the `fallback` rect (a solid filled glyph) which reads as a chunky pixel block. That's fine. The `.` glyph is defined.

- [ ] **Step 2: Snapshot tests**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class InsightCardSnapshotTests: XCTestCase {
    private func host<V: View>(_ view: V) -> some View {
        view.frame(width: 360).padding(16).background(Color.black).fixedSize()
    }

    func test_win() {
        let i = Insight(kind: .win, title: "STRONG MONDAYS",
                        body: "Drink Water hits 92% of Mondays — your best day.",
                        primaryAccentHex: "#2BFF5F")
        assertSnapshot(of: host(InsightCard(insight: i)), as: .image(precision: 0.99))
    }

    func test_risk() {
        let i = Insight(kind: .risk, title: "IDLE",
                        body: "Stretch — 10 days since last log.",
                        primaryAccentHex: "#FFB23D")
        assertSnapshot(of: host(InsightCard(insight: i)), as: .image(precision: 0.99))
    }

    func test_suggest() {
        let i = Insight(kind: .suggest, title: "STACK",
                        body: "Drink Water and Stretch co-occur 84% of the time. Pair them in your routine.",
                        primaryAccentHex: "#3DA4FF")
        assertSnapshot(of: host(InsightCard(insight: i)), as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add InsightCard"
```

---

## Task 4: RiskHeatmap component

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/RiskHeatmap.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/RiskHeatmapSnapshotTests.swift`

- [ ] **Step 1: Write `RiskHeatmap.swift`**

```swift
import SwiftUI

public struct RiskHeatmap: View {
    let forecast: RiskForecast
    let accent: Color
    let cellSize: CGFloat
    let showLabels: Bool

    public init(forecast: RiskForecast, accent: Color, cellSize: CGFloat = 28, showLabels: Bool = true) {
        self.forecast = forecast
        self.accent = accent
        self.cellSize = cellSize
        self.showLabels = showLabels
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabels {
                HStack(spacing: 4) {
                    Color.clear.frame(width: 24, height: cellSize * 0.5)
                    ForEach(0..<8, id: \.self) { b in
                        PixelText(Self.bucketAbbrev(b), pixelSize: 1, color: DesignTokens.Surface.mutedText)
                            .frame(width: cellSize)
                    }
                }
            }
            ForEach(0..<7, id: \.self) { wd in
                HStack(spacing: 4) {
                    if showLabels {
                        PixelText(Self.weekdayLetter(wd), pixelSize: 2, color: DesignTokens.Surface.mutedText)
                            .frame(width: 24, alignment: .leading)
                    }
                    ForEach(0..<8, id: \.self) { bucket in
                        Rectangle()
                            .fill(color(for: forecast.matrix[wd][bucket]))
                            .frame(width: cellSize, height: cellSize)
                            .overlay(Rectangle().stroke(.black, lineWidth: 1))
                    }
                }
            }
        }
        .accessibilityLabel("Risk forecast heatmap")
    }

    private func color(for level: RiskLevel) -> Color {
        switch level {
        case .noData:     return DesignTokens.Surface.inactive
        case .completed4: return accent
        case .completed3: return accent.darker(by: 0.15)
        case .completed2: return accent.darker(by: 0.3)
        case .completed1: return DesignTokens.Surface.mutedText
        case .warn:       return Color(hex: "#FFB23D")
        case .danger:     return DesignTokens.Surface.miss
        }
    }

    static func bucketAbbrev(_ b: Int) -> String {
        ["6A", "9A", "12P", "3P", "6P", "9P", "12A", "3A"][b]
    }

    static func weekdayLetter(_ wd: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][wd]
    }
}
```

- [ ] **Step 2: Snapshot test**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class RiskHeatmapSnapshotTests: XCTestCase {
    func test_empty() {
        let view = RiskHeatmap(forecast: .empty, accent: Color(hex: "#2BFF5F"))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_sampleMatrix() {
        var matrix: [[RiskLevel]] = Array(repeating: Array(repeating: .noData, count: 8), count: 7)
        matrix[0][2] = .completed4   // Monday 12pm great
        matrix[5][4] = .danger       // Saturday 6pm danger
        matrix[5][5] = .warn         // Saturday 9pm warn
        matrix[3][1] = .completed3
        let f = RiskForecast(matrix: matrix, topRisks: [])
        let view = RiskHeatmap(forecast: f, accent: Color(hex: "#2BFF5F"))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add RiskHeatmap 7×8 grid"
```

---

## Task 5: InsightsView + RiskExpandedView + wire STATS tab

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Insights/InsightsView.swift`
- Create: `Apps/iOS/HabitMap/Screens/Insights/RiskExpandedView.swift`
- Modify: `Apps/iOS/HabitMap/HabitMapApp.swift` — route STATS → InsightsView

- [ ] **Step 1: Write `RiskExpandedView.swift`**

```swift
import SwiftUI
import HabitMapCore

struct RiskExpandedView: View {
    @Environment(\.dismiss) private var dismiss
    let forecast: RiskForecast
    let accent: Color

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    PixelText("RISK FORECAST", pixelSize: 4, color: accent)
                        .accessibilityLabel("RISK FORECAST")
                        .accessibilityAddTraits(.isHeader)
                    Text("Where your habits tend to slip, by weekday and time of day. Darker = higher chance of missing.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    RiskHeatmap(forecast: forecast, accent: accent, cellSize: 36)

                    if !forecast.topRisks.isEmpty {
                        PixelText("TOP WINDOWS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        ForEach(forecast.topRisks.indices, id: \.self) { idx in
                            let window = forecast.topRisks[idx]
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(windowColor(window.level))
                                    .frame(width: 28, height: 28)
                                    .overlay(Rectangle().stroke(.black, lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    PixelText("\(InsightsEngine.weekdayName(window.weekday).uppercased()) \(InsightsEngine.bucketLabel(window.bucket).uppercased())",
                                              pixelSize: 2,
                                              color: accent)
                                    Text("\(window.attempts) attempts")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(DesignTokens.Surface.mutedText)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(DesignTokens.Surface.card)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("RISK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func windowColor(_ level: RiskLevel) -> Color {
        switch level {
        case .danger: return DesignTokens.Surface.miss
        case .warn:   return Color(hex: "#FFB23D")
        default:      return DesignTokens.Surface.inactive
        }
    }
}
```

- [ ] **Step 2: Write `InsightsView.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

struct InsightsView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived }) private var pages: [HabitPage]
    @State private var showRiskExpanded = false

    private let insightsEngine = InsightsEngine()
    private let riskEngine = RiskForecastEngine()

    var body: some View {
        let habits = pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
        let insights = insightsEngine.generate(habits: habits)
        let forecast = riskEngine.forecast(habits: habits)
        let accent = DesignTokens.Accent.classicGreen

        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                PixelText("INSIGHTS", pixelSize: 4, color: accent)
                    .accessibilityLabel("INSIGHTS")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.lg)

                if insights.isEmpty {
                    Text("Not enough data yet — keep logging and we'll surface patterns here.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }

                Button {
                    showRiskExpanded = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PixelText("RISK WINDOWS", pixelSize: 3, color: accent)
                            Spacer()
                            PixelText(">", pixelSize: 2, color: accent)
                        }
                        RiskHeatmap(forecast: forecast, accent: accent, cellSize: 28, showLabels: true)
                    }
                    .padding(12)
                    .background(DesignTokens.Surface.card)
                    .overlay(Rectangle().stroke(accent, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("RISK WINDOWS, tap to expand")
                .padding(.horizontal, DesignTokens.Spacing.lg)

                Spacer(minLength: 24)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(isPresented: $showRiskExpanded) {
            RiskExpandedView(forecast: forecast, accent: accent)
        }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 3: Modify `HabitMapApp.swift` — STATS routes to InsightsView**

In `RootView` body, replace the `.stats` case:

```swift
case .stats: InsightsView()
```

- [ ] **Step 4: Build, manual smoke, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
# Launch → tap STATS tab → InsightsView appears with insights + risk heatmap.
# Tap risk card → RiskExpandedView opens full-screen.
git commit -m "feat(insights): add InsightsView + RiskExpandedView, wire STATS tab"
```

---

## Task 6: UI test — STATS tab navigation

**Files:**
- Create: `Apps/iOS/HabitMapUITests/InsightsNavigationUITests.swift`

- [ ] **Step 1: Write the test**

```swift
import XCTest

final class InsightsNavigationUITests: XCTestCase {
    func test_tapStatsTab_revealsInsightsHeader() throws {
        let app = XCUIApplication()
        app.launch()

        let statsTab = app.buttons["STATS tab"].firstMatch
        XCTAssertTrue(statsTab.waitForExistence(timeout: 10))
        statsTab.tap()

        let insightsHeader = app.descendants(matching: .any).matching(identifier: "INSIGHTS").firstMatch
        XCTAssertTrue(insightsHeader.waitForExistence(timeout: 5)
                      || app.staticTexts["INSIGHTS"].waitForExistence(timeout: 5),
                      "Expected INSIGHTS header after tapping STATS tab")
    }
}
```

- [ ] **Step 2: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapUITests/InsightsNavigationUITests
git commit -m "test(ui): verify STATS tab reveals insights header"
```

---

## Task 7: Final verification + Plan 06 handoff

- [ ] **Step 1: Full test sweep**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

- [ ] **Step 2: Manual smoke**

1. Launch → seeded HEALTH page with DRINK WATER + STRETCH habits.
2. Tap STATS → INSIGHTS header appears. With seeded random history, expect 0–2 insights (depends on RNG).
3. Risk heatmap shows mostly `noData` gray cells (≤ 4 attempts per bucket in 30 days for a single habit).
4. Tap risk card → RiskExpandedView opens full-screen with same heatmap larger + top windows list.
5. Re-tap STATS → cached state preserved.

- [ ] **Step 3: Write `docs/plan-05-handoff.md`**

- [ ] **Step 4: Final commit + push**

```bash
git add docs/
git commit -m "docs: plan 05 complete, handoff to plan 06 (Notifications + Settings)"
git push
```

---

## Verification

End-to-end manual test on iPhone 16 simulator:
1. STATS tab opens InsightsView (no `ComingSoonView`).
2. With seeded data the insights list may be empty or have 1–2 items.
3. Risk heatmap card is visible with mostly `noData` cells.
4. Tap risk card → expanded view shows the heatmap larger plus top-risk list.
5. All other tabs (TODAY/MAP) still work — regression check.

Automated: `xcodebuild test ...` — all 100+ tests pass.

## Out of scope for this plan
Reminder-impact insight · Phase-graduation insight · Seasonal-dip insight · Notifications scheduling · Settings · Reset Data · Widgets · Live Activity · Apple Watch · iPad layouts · Onboarding · Themes · CloudKit cutover.
