# Habit Map — Plan 04: Heat Map Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tapping MAP in the tab bar opens a year heat map: a 365-cell pixel grid showing aggregate daily completion, with filter chips (All + one per page), a streak card (30-day consistency %, current streak, best streak), and a tap-cell-to-open day detail bottom sheet. The day detail lists every habit's status for that day and lets the user write/edit a journal note tied to that day.

**Architecture:** A small `StatsService` (`@MainActor`) on top of `HabitRepository` computes streaks and consistency. Year heat map is a Grid of `HabitCell` views (`drawingGroup`-rasterized per cell, fast enough at 365). Day detail is a `.sheet`. TabBar is hoisted from `TodayView` into `RootView` so every screen renders below the same bar; screens become content-only.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 17+, SwiftData. No new dependencies.

---

## Context

Plans 01-03 shipped: foundation, pages/habits CRUD, HealthKit. The TabBar component visually shows 4 tabs but only TODAY routes anywhere. MAP, STATS, SETUP are placeholders.

This plan delivers:
- A working MAP screen with filter / streak card / 365-cell grid / day detail
- A tab-navigation refactor (TabBar in `RootView`, screens are content-only)
- A `StatsService` with streak + consistency math
- A `Day-detail` sheet with journal note editing
- New components: `FilterChip`, `StreakCard`, `YearGrid`, `DayDetailRow`

**Defining "complete" for streaks/consistency.** A day counts as "complete" for the filter scope when every scheduled habit in scope hit `progressFraction >= 1.0`. This matches how most trackers compute streaks; the recovery-rate from Plan 01 covers the "non-punishing" angle elsewhere.

**Out of scope** (still on the list): Insights · Risk Forecast · Notification scheduling · Settings · Reset Data · Widgets · Live Activity · Apple Watch · iPad layouts · Onboarding · Themes · CloudKit cutover.

---

## File Structure (new additions)

```
Packages/HabitMapCore/
  Sources/HabitMapCore/
    Services/
      StatsService.swift                # @MainActor — streaks + consistency
    Components/
      FilterChip.swift                  # 1-pixel pill button
      StreakCard.swift                  # 3-column streak display
      YearGrid.swift                    # 365-cell grid using HabitCell
    Models/
      DailyStatus.swift                 # struct describing one habit's status on one day
  Tests/HabitMapCoreTests/
    StatsServiceTests.swift             # streak + consistency math
    FilterChipSnapshotTests.swift
    StreakCardSnapshotTests.swift
    YearGridSnapshotTests.swift

Apps/iOS/HabitMap/
  Screens/
    Map/
      MapView.swift                     # filter chips + streak + grid + sheet
      DayDetailSheet.swift              # habits-for-day list + journal note
    ComingSoonView.swift                # placeholder for STATS/SETUP (Plans 05/06)
  HabitMapApp.swift                     # (modified) RootView refactor
  Screens/Today/
    TodayView.swift                     # (modified) TabBar removed from here
    TabBar.swift                        # (modified) accepts onSelect callback
HabitMapUITests/
  MapNavigationUITests.swift            # tap MAP tab → grid appears
```

---

## Task 1: StatsService — streaks + consistency

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/StatsService.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/StatsServiceTests.swift`

- [ ] **Step 1: Write `StatsService.swift`**

```swift
import Foundation

@MainActor
public final class StatsService {
    public init() {}

    /// A day is "complete" for the scope when every scheduled habit in scope hit progressFraction >= 1.0 on that date.
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

    /// Current streak: consecutive complete days going backwards from today (or yesterday if today not yet complete).
    /// We start at yesterday so today's incomplete state doesn't snap the streak before the day ends.
    public func currentStreak(habits: [Habit], asOf: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        var streak = 0
        // If today is complete, count it.
        if isComplete(on: today, habits: habits) { streak += 1 }
        // Walk backwards from yesterday until we hit a scheduled-but-incomplete day.
        var offset = 1
        while offset < 365 * 2 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            // Skip days where nothing was scheduled (don't break the streak).
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

    /// Best (longest-ever) streak across the habits' completion history.
    public func bestStreak(habits: [Habit], asOf: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        // Look back up to 2 years; cheap enough at O(2*365).
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
```

- [ ] **Step 2: Write `StatsServiceTests.swift`**

```swift
import XCTest
import SwiftData
@testable import HabitMapCore

final class StatsServiceTests: XCTestCase {
    var container: ModelContainer!
    var stats: StatsService!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        stats = StatsService()
    }

    @MainActor
    private func makeHabit(name: String = "H", weekdayMask: Int8 = 0b01111111) -> Habit {
        let habit = Habit(name: name, emoji: "x", accentHex: "#FFFFFF",
                          type: .manualOnce, targetReps: 1,
                          weekdayMask: weekdayMask)
        container.mainContext.insert(habit)
        try? container.mainContext.save()
        return habit
    }

    @MainActor
    private func completeHabit(_ habit: Habit, daysAgo: Int) {
        let cal = Calendar.current
        let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
        let c = HabitCompletion(date: date, reps: 1, habit: habit)
        container.mainContext.insert(c)
        try? container.mainContext.save()
    }

    @MainActor
    func test_isComplete_allHabitsDone_isTrue() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        completeHabit(a, daysAgo: 0); completeHabit(b, daysAgo: 0)
        XCTAssertTrue(stats.isComplete(on: Date(), habits: [a, b]))
    }

    @MainActor
    func test_isComplete_oneHabitMissing_isFalse() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        completeHabit(a, daysAgo: 0)
        XCTAssertFalse(stats.isComplete(on: Date(), habits: [a, b]))
    }

    @MainActor
    func test_isComplete_noScheduledHabits_isFalse() {
        let restOnly = makeHabit(weekdayMask: 0)
        XCTAssertFalse(stats.isComplete(on: Date(), habits: [restOnly]))
    }

    @MainActor
    func test_currentStreak_zeroWhenTodayMissedAndYesterdayMissed() {
        let h = makeHabit()
        XCTAssertEqual(stats.currentStreak(habits: [h]), 0)
    }

    @MainActor
    func test_currentStreak_fiveConsecutiveDays() {
        let h = makeHabit()
        for offset in 0..<5 { completeHabit(h, daysAgo: offset) }
        XCTAssertEqual(stats.currentStreak(habits: [h]), 5)
    }

    @MainActor
    func test_currentStreak_brokenByMissedDay() {
        let h = makeHabit()
        completeHabit(h, daysAgo: 0)
        completeHabit(h, daysAgo: 1)
        // day 2 missed
        completeHabit(h, daysAgo: 3)
        XCTAssertEqual(stats.currentStreak(habits: [h]), 2)
    }

    @MainActor
    func test_bestStreak_findsLongestRunEvenIfBroken() {
        let h = makeHabit()
        // Run of 7 ending 10 days ago, then run of 3 ending today
        for offset in 10..<17 { completeHabit(h, daysAgo: offset) }
        for offset in 0..<3 { completeHabit(h, daysAgo: offset) }
        XCTAssertEqual(stats.bestStreak(habits: [h]), 7)
    }

    @MainActor
    func test_consistency_halfComplete_isHalf() {
        let h = makeHabit()
        for offset in 0..<30 where offset.isMultiple(of: 2) { completeHabit(h, daysAgo: offset) }
        XCTAssertEqual(stats.consistency(habits: [h], window: 30), 0.5, accuracy: 0.05)
    }

    @MainActor
    func test_consistency_noScheduledDays_returnsOne() {
        let h = makeHabit(weekdayMask: 0)
        XCTAssertEqual(stats.consistency(habits: [h], window: 30), 1.0)
    }

    @MainActor
    func test_averageProgress_partial() {
        let a = makeHabit(name: "A"); let b = makeHabit(name: "B")
        completeHabit(a, daysAgo: 0)
        // b not done → 0.5 avg
        XCTAssertEqual(stats.averageProgress(on: Date(), habits: [a, b]), 0.5, accuracy: 0.01)
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
xcodegen generate
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/StatsServiceTests
git add Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "feat(stats): add StatsService with streaks and 30-day consistency"
```

---

## Task 2: FilterChip component

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/FilterChip.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/FilterChipSnapshotTests.swift`

- [ ] **Step 1: Write `FilterChip.swift`**

```swift
import SwiftUI

public struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    public init(label: String, isSelected: Bool, accent: Color, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            PixelText(label, pixelSize: 2, color: isSelected ? .black : accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? accent : DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(isSelected ? accent.darker(by: 0.2) : accent, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
```

- [ ] **Step 2: Snapshot tests**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class FilterChipSnapshotTests: XCTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_selected() {
        let view = FilterChip(label: "ALL", isSelected: true, accent: accent) {}
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
    func test_unselected() {
        let view = FilterChip(label: "HEALTH", isSelected: false, accent: accent) {}
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
git commit -m "feat(components): add FilterChip pill button"
```

---

## Task 3: StreakCard component

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/StreakCard.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/StreakCardSnapshotTests.swift`

- [ ] **Step 1: Write `StreakCard.swift`**

```swift
import SwiftUI

public struct StreakCard: View {
    let consistency: Double         // 0..1
    let currentStreak: Int
    let bestStreak: Int
    let accent: Color

    public init(consistency: Double, currentStreak: Int, bestStreak: Int, accent: Color) {
        self.consistency = consistency
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.accent = accent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            cell(label: "30D", value: "\(Int(consistency * 100))%")
            divider
            cell(label: "STREAK", value: "\(currentStreak)")
            divider
            cell(label: "BEST", value: "\(bestStreak)")
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(accent, lineWidth: 2))
    }

    private func cell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            PixelText(value, pixelSize: 4, color: accent)
            PixelText(label, pixelSize: 2, color: DesignTokens.Surface.mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.Surface.cardBorder)
            .frame(width: 1)
    }
}
```

- [ ] **Step 2: Snapshot test**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class StreakCardSnapshotTests: XCTestCase {
    func test_default() {
        let view = StreakCard(consistency: 0.81, currentStreak: 12, bestStreak: 34,
                              accent: Color(hex: "#2BFF5F"))
            .frame(width: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_zeros() {
        let view = StreakCard(consistency: 0.0, currentStreak: 0, bestStreak: 0,
                              accent: Color(hex: "#3DA4FF"))
            .frame(width: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add StreakCard with 30D% / streak / best"
```

---

## Task 4: YearGrid — 365-cell heat map

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/YearGrid.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/YearGridSnapshotTests.swift`

- [ ] **Step 1: Write `YearGrid.swift`**

```swift
import SwiftUI

public struct YearGrid: View {
    let habits: [Habit]
    let accent: Color
    let columns: Int
    let days: Int
    let onTap: (Date) -> Void

    public init(habits: [Habit], accent: Color, columns: Int = 20, days: Int = 365, onTap: @escaping (Date) -> Void) {
        self.habits = habits
        self.accent = accent
        self.columns = columns
        self.days = days
        self.onTap = onTap
    }

    public var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let rows = Int((Double(days) / Double(columns)).rounded(.up))

        GeometryReader { geo in
            let cellSize = (geo.size.width - CGFloat(columns - 1) * 2) / CGFloat(columns)
            VStack(spacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < days {
                                let offset = days - 1 - index
                                let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
                                cell(for: date, size: cellSize, today: today, cal: cal)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
    }

    @ViewBuilder
    private func cell(for date: Date, size: CGFloat, today: Date, cal: Calendar) -> some View {
        let level = combinedLevel(on: date, today: today, cal: cal)
        let isToday = cal.isDate(date, inSameDayAs: today)
        HabitCell(level: level, accent: accent, isToday: isToday, size: size)
            .contentShape(Rectangle())
            .onTapGesture { onTap(date) }
            .accessibilityLabel(Self.dayLabel(date))
    }

    private func combinedLevel(on date: Date, today: Date, cal: Calendar) -> CellLevel {
        if date > today { return .future }
        let active = habits.filter { !$0.isArchived && !$0.isPaused }
        let scheduled = active.filter { $0.isScheduled(date) }
        if scheduled.isEmpty { return .empty }
        let avg = scheduled.map { $0.progressFraction(on: date) }.reduce(0, +) / Double(scheduled.count)
        return CellLevel.from(progress: avg)
    }

    private static func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
```

- [ ] **Step 2: Snapshot test**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
import SwiftData
@testable import HabitMapCore

final class YearGridSnapshotTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
    }

    @MainActor
    func test_emptyGrid() {
        let view = YearGrid(habits: [], accent: Color(hex: "#2BFF5F")) { _ in }
            .frame(width: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add YearGrid 365-cell heat map"
```

---

## Task 5: Hoist TabBar from TodayView to RootView

**Files:**
- Modify: `Apps/iOS/HabitMap/Screens/Today/TabBar.swift` — accept onSelect callback
- Modify: `Apps/iOS/HabitMap/Screens/Today/TodayView.swift` — remove inline TabBar
- Modify: `Apps/iOS/HabitMap/HabitMapApp.swift` — render TabBar in `RootView`, add tab state
- Create: `Apps/iOS/HabitMap/Screens/ComingSoonView.swift` — placeholder for STATS/SETUP

- [ ] **Step 1: Modify `TabBar.swift` to accept tap callback**

```swift
import SwiftUI
import HabitMapCore

public enum HabitMapTab: String, CaseIterable {
    case today, map, stats, setup
}

struct TabBar: View {
    let active: HabitMapTab
    let onSelect: (HabitMapTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, icon: .home,  label: "TODAY")
            tab(.map,   icon: .grid,  label: "MAP")
            tab(.stats, icon: .chart, label: "STATS")
            tab(.setup, icon: .gear,  label: "SETUP")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Surface.bg)
        .overlay(Rectangle().fill(DesignTokens.Surface.cardBorder).frame(height: 1), alignment: .top)
    }

    private func tab(_ tab: HabitMapTab, icon: PixelIconName, label: String) -> some View {
        let color = (active == tab) ? Color(hex: "#2BFF5F") : DesignTokens.Surface.dimText
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                PixelIcon(icon, color: color, size: 24)
                PixelText(label, pixelSize: 2, color: color)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) tab")
        .accessibilityAddTraits(active == tab ? [.isButton, .isSelected] : .isButton)
    }
}
```

- [ ] **Step 2: Modify `TodayView.swift` — remove inline TabBar**

Remove the bottom VStack containing `PageDots + TabBar`. Keep only `PageDots`. Move the FAB padding adjustment (was `padding(.bottom, 96)`) to `padding(.bottom, 16)` since TabBar lives elsewhere now; RootView's outer layout handles the inset.

```swift
// At the bottom of TodayView body, replace the VStack(spacing: 8) { PageDots ; TabBar } with:
VStack {
    Spacer()
    let active = pages.filter { !$0.isArchived }
    if !active.isEmpty {
        PageDots(count: active.count,
                 activeIndex: active.firstIndex { $0.id == selectedPageID } ?? 0,
                 activeColor: active.first { $0.id == selectedPageID }?.accentColor
                                  ?? DesignTokens.Surface.mutedText)
            .padding(.bottom, 8)
    }
}
.allowsHitTesting(false)

// And FAB padding:
.overlay(alignment: .bottomTrailing) {
    if let id = selectedPageID,
       let page = pages.first(where: { $0.id == id }) {
        FAB(accent: page.accentColor) { wizardPage = page }
            .padding(.trailing, DesignTokens.Spacing.lg)
            .padding(.bottom, 16)
            .accessibilityLabel("Add habit to \(page.name)")
    }
}
```

- [ ] **Step 3: Write `ComingSoonView.swift`**

```swift
import SwiftUI
import HabitMapCore

struct ComingSoonView: View {
    let title: String
    let plan: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            PixelText(title, pixelSize: 5, color: DesignTokens.Accent.classicGreen)
            PixelText("COMING IN \(plan)", pixelSize: 2, color: DesignTokens.Surface.mutedText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Surface.bg)
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 4: Modify `HabitMapApp.swift` — RootView holds tab state + renders TabBar**

```swift
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: HealthSyncService
    @State private var activeTab: HabitMapTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            // Screen content, padded to clear the tab bar (~64pt).
            Group {
                switch activeTab {
                case .today: TodayView()
                case .map:   MapView()
                case .stats: ComingSoonView(title: "STATS", plan: "PLAN 05")
                case .setup: ComingSoonView(title: "SETUP", plan: "PLAN 06")
                }
            }
            .padding(.bottom, 80)

            TabBar(active: activeTab) { tab in activeTab = tab }
        }
        .background(DesignTokens.Surface.bg)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await sync.syncToday() }
            }
        }
    }
}
```

- [ ] **Step 5: Build, manual smoke, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
# Launch in simulator → tap MAP / STATS / SETUP tabs → screens switch.
git commit -m "refactor(nav): hoist TabBar to RootView, screens are now content-only"
```

---

## Task 6: DayDetailSheet — habits-for-day list + journal note

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Map/DayDetailSheet.swift`

The sheet shows one row per habit that was scheduled on the given day, with their progress state, plus a journal note field stored on a "marker" `HabitCompletion` (any habit's completion on that day will do; we pick the first scheduled habit and write the note there for simplicity).

> Tradeoff: the note attaches to a single habit's completion record, not a day-level entity. This is fine for v1 — Plan 06 may introduce a `DayNote` entity if needed. Reading: we read the note from whichever scheduled habit has one.

- [ ] **Step 1: Write `DayDetailSheet.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    let date: Date
    let habits: [Habit]
    let accent: Color

    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    PixelText(headerDate, pixelSize: 3, color: accent)

                    VStack(spacing: 8) {
                        ForEach(scheduled) { habit in
                            habitRow(habit)
                        }
                        if scheduled.isEmpty {
                            PixelText("REST DAY", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        PixelText("NOTE", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        TextEditor(text: $note)
                            .scrollContentBackground(.hidden)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                            .frame(minHeight: 100)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("DAY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { loadNote() }
        }
        .preferredColorScheme(.dark)
    }

    private var scheduled: [Habit] {
        habits.filter { !$0.isArchived && !$0.isPaused && $0.isScheduled(date) }
    }

    private var headerDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE - MMM d"
        return f.string(from: date).uppercased()
    }

    @ViewBuilder
    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 12) {
            HabitCell(level: habit.cellLevel(on: date),
                      accent: habit.accentColor,
                      isToday: Calendar.current.isDateInToday(date),
                      size: 32)
            VStack(alignment: .leading, spacing: 2) {
                PixelText(habit.name, pixelSize: 2, color: habit.accentColor)
                Text(progressLabel(habit))
                    .font(.system(.caption2, design: .monospaced).weight(.heavy))
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }

    private func progressLabel(_ habit: Habit) -> String {
        switch habit.type {
        case .manualOnce:    return habit.progressFraction(on: date) >= 1.0 ? "DONE" : "MISSED"
        case .manualMultiple:
            let reps = habit.completion(on: date)?.reps ?? 0
            return "\(reps) / \(habit.targetReps)"
        case .autoHealth:
            let reps = habit.completion(on: date)?.reps ?? 0
            let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
            return "\(reps) / \(goal)"
        case .inverse:
            return (habit.completion(on: date)?.slipped == true) ? "SLIPPED" : "CLEAN"
        }
    }

    private func loadNote() {
        // Find any completion on this day with a non-nil note.
        for habit in habits {
            if let n = habit.completion(on: date)?.note, !n.isEmpty {
                note = n
                return
            }
        }
        note = ""
    }

    private func save() {
        guard let anchor = scheduled.first else { dismiss(); return }
        if let existing = anchor.completion(on: date) {
            existing.note = note.isEmpty ? nil : note
        } else {
            let completion = HabitCompletion(date: date, reps: 0, note: note.isEmpty ? nil : note, habit: anchor)
            repo.context.insert(completion)
        }
        try? repo.context.save()
        dismiss()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(map): add DayDetailSheet with habits-for-day + journal note"
```

---

## Task 7: MapView — the heat map screen

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Map/MapView.swift`

- [ ] **Step 1: Write `MapView.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

struct MapView: View {
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var pages: [HabitPage]
    @EnvironmentObject private var repo: HabitRepository

    @State private var selectedPageID: UUID? = nil   // nil = "All"
    @State private var detailDate: Date?
    private let stats = StatsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                PixelText("HEAT MAP", pixelSize: 4, color: accent)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .accessibilityAddTraits(.isHeader)

                filterChips
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                StreakCard(consistency: stats.consistency(habits: filteredHabits),
                           currentStreak: stats.currentStreak(habits: filteredHabits),
                           bestStreak: stats.bestStreak(habits: filteredHabits),
                           accent: accent)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                YearGrid(habits: filteredHabits, accent: accent) { date in
                    detailDate = date
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)

                legend.padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(item: Binding(get: { detailDate.map { DateRef(date: $0) } },
                             set: { detailDate = $0?.date })) { ref in
            DayDetailSheet(date: ref.date, habits: filteredHabits, accent: accent)
                .environmentObject(repo)
        }
        .preferredColorScheme(.dark)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "ALL",
                           isSelected: selectedPageID == nil,
                           accent: DesignTokens.Accent.classicGreen) {
                    selectedPageID = nil
                }
                ForEach(pages) { page in
                    FilterChip(label: page.name,
                               isSelected: selectedPageID == page.id,
                               accent: page.accentColor) {
                        selectedPageID = page.id
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("LESS")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .tracking(1.0)
                .foregroundColor(DesignTokens.Surface.mutedText)
            HabitCell(level: .empty, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p25, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p50, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p75, accent: accent, isToday: false, size: 10)
            HabitCell(level: .p100, accent: accent, isToday: false, size: 10)
            Text("MORE")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .tracking(1.0)
                .foregroundColor(DesignTokens.Surface.mutedText)
        }
    }

    private var accent: Color {
        if let id = selectedPageID, let page = pages.first(where: { $0.id == id }) {
            return page.accentColor
        }
        return DesignTokens.Accent.classicGreen
    }

    private var filteredHabits: [Habit] {
        if let id = selectedPageID, let page = pages.first(where: { $0.id == id }) {
            return (page.habits ?? []).filter { !$0.isArchived && !$0.isPaused }
        }
        return pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused } }
    }
}

/// Identifiable wrapper for `.sheet(item:)` since Date isn't Identifiable.
private struct DateRef: Identifiable {
    let date: Date
    var id: Date { date }
}
```

- [ ] **Step 2: Build, manual smoke, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
# Launch → tap MAP tab → heat map appears → tap a cell → DayDetailSheet opens.
git commit -m "feat(map): add MapView with filter chips, StreakCard, year grid, day sheet"
```

---

## Task 8: UI test — MapView navigation

**Files:**
- Create: `Apps/iOS/HabitMapUITests/MapNavigationUITests.swift`

- [ ] **Step 1: Write `MapNavigationUITests.swift`**

```swift
import XCTest

final class MapNavigationUITests: XCTestCase {
    func test_tapMapTab_revealsHeatMap() throws {
        let app = XCUIApplication()
        app.launch()

        let mapTab = app.buttons["MAP tab"].firstMatch
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        mapTab.tap()

        XCTAssertTrue(app.staticTexts["HEAT MAP"].waitForExistence(timeout: 5)
                      || app.descendants(matching: .any)["HEAT MAP"].waitForExistence(timeout: 5),
                      "Expected HEAT MAP header after tapping MAP tab")

        let allChip = app.buttons["ALL"].firstMatch
        XCTAssertTrue(allChip.waitForExistence(timeout: 5),
                      "Expected ALL filter chip on MapView")
    }
}
```

- [ ] **Step 2: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapUITests/MapNavigationUITests
git commit -m "test(ui): verify MAP tab navigation reveals heat map"
```

---

## Task 9: Final verification + Plan 05 handoff

- [ ] **Step 1: Full test sweep**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

- [ ] **Step 2: Manual smoke**

1. Launch app → Today tab is active (default), HEALTH page + DRINK WATER habit visible.
2. Tap MAP tab → heat map appears: filter chips, streak card, 365-cell grid, legend.
3. Tap a green cell from the seeded 30-day history → DayDetailSheet opens with that day's habits.
4. Type a note → tap Save → sheet dismisses. Re-open the same day → note persists.
5. Tap a different page filter chip → grid and streak card recolor to that page's accent.
6. Tap a future cell (last few cells) → no action / they show as dashed-border future cells.
7. Tap STATS / SETUP → ComingSoonView appears.

- [ ] **Step 3: Write `docs/plan-04-handoff.md`**

- [ ] **Step 4: Final commit**

```bash
git add docs/
git commit -m "docs: plan 04 complete, handoff to plan 05 (Insights + Risk Forecast)"
```

---

## Verification

End-to-end manual test on iPhone 16 simulator:
1. Today still works (regression check).
2. MAP tab opens heat map with seeded data.
3. Filter chips switch scope (All ↔ specific page).
4. Streak card numbers reflect the filter.
5. Tap a cell → DayDetailSheet shows that day's habits with their status.
6. Notes persist across re-opens.
7. STATS / SETUP show ComingSoonView placeholders.

Automated: `xcodebuild test ...` — all 90+ tests pass.

## Out of scope for this plan
Insights · Risk Forecast · Notification scheduling · Settings · Reset Data · Widgets · Live Activity · Apple Watch · iPad layouts · Onboarding · Themes · CloudKit cutover · per-habit detail view from DayDetailSheet (tap habit row).
