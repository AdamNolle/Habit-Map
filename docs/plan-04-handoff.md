# Plan 04 — Heat Map → Plan 05 handoff

## What ships

MAP tab is live. Users can:

- **Tap MAP** in the tab bar to reach a year heat map of their combined progress.
- **Filter** by single page or "ALL" — the streak card, year grid, and accent recolor accordingly.
- See **30-day consistency %, current streak, and best streak** in the `StreakCard` (computed from `StatsService`).
- See **365 days of history** as a 20×19 cell grid using the existing `HabitCell` pixel-art. Combined cells show the average progress across all scheduled habits.
- **Tap a cell** to open a `DayDetailSheet` listing every habit scheduled that day with its status, plus a journal note editor.
- **Write/edit notes** that persist on the underlying `HabitCompletion.note` field. Notes survive cold launch and re-opens.

Also in this plan:
- **Tab navigation refactor:** `TabBar` moved from `TodayView` into `RootView`. Screens are now content-only. `STATS` and `SETUP` show a `ComingSoonView` placeholder until Plans 05/06.

## Test coverage

**99 tests pass** (94 unit/snapshot + 5 UI). Plan 04 added:

| Suite | Count | Type |
|---|---:|---|
| **`StatsServiceTests`** | 10 | unit |
| **`FilterChipSnapshotTests`** | 2 | snapshot |
| **`StreakCardSnapshotTests`** | 2 | snapshot |
| **`YearGridSnapshotTests`** | 1 | snapshot |
| **`MapNavigationUITests`** | 1 | UI |

Plus all 79 prior unit/snapshot tests and 3 prior UI tests still green.

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

## Deviations from the plan

1. **Day note storage simplification.** The day-journal field hijacks `HabitCompletion.note` on the first scheduled habit's completion record for that day. This is fine for v1 — Plan 06's Reset Data / Settings work or a later Insights pass might introduce a dedicated `DayNote` entity. Reading is forgiving: any habit on the day with a non-empty note wins.
2. **`MapView` constructs its own `StatsService`** rather than receiving it via environment. The service is stateless (no `@Published`) and cheap to construct; no value in injecting it. Future versions that cache results may want to hoist it.
3. **`YearGrid` renders one `HabitCell` view per day**, not a single `Canvas`. 365 individual cells render fine on iPhone 16 (each is already `drawingGroup`-rasterized). Switch to a single `Canvas` if perf becomes a problem on older devices.
4. **`PixelText` headers need explicit `.accessibilityLabel(...)`** to be discoverable by UI tests — discovered the hard way when `MapNavigationUITests` failed initially. Same pattern as Plan 02; documenting here so the next plan author doesn't trip.
5. **Future dates in the year grid are rendered as `.future` cells** (dashed border, dark fill). Tapping them still opens the day detail but the sheet shows scheduled habits (with no progress yet) — slightly weird but harmless; users will probably tap recent days. Spec is silent on whether future days should be interactive.

## Known limitations (lands later)

- **No day-detail-from-Today.** Long-press on a `HabitRow` opens `HabitDetailView` (single habit), not `DayDetailSheet` (whole day). The day-detail is reachable only from the map. Could add a "today" shortcut later if useful.
- **Note edits use plain `TextEditor`** with system font, not pixel-art. Pixel-text input is hard to do well; this is a deliberate compromise.
- **`StreakCard` shows aggregate consistency only.** Per-habit consistency lives on `Habit.recoveryRate` (Plan 01) but isn't surfaced in the heat map UI yet. Insights (Plan 05) will surface per-habit numbers.
- **CloudKit still off**, BGAppRefreshTask still scheduled but never actually fires in simulator (iOS reserves background time for real devices).

## Open questions for Plan 05 (Insights + Risk Forecast)

- **Insights tab routing.** Should the `STATS` tab open InsightsView, or should we add a 5th tab? Recommendation: keep 4 tabs, route STATS → Insights.
- **Insight categories.** Spec §11.1 lists 7 algorithms (strongest day-of-week, reminder impact, time-of-day skip risk, idle habit, stacking, phase graduation, seasonal dip). Implement all 7 in Plan 05 or split into Plan 05a/b? Recommendation: ship strongest day-of-week + reminder impact + idle habit + stacking in Plan 05 (the 4 most actionable). Defer time-of-day skip risk (needs `loggedAt` time analysis), phase graduation (needs explicit user goal-setting), seasonal dip (needs ≥ 1 year of data) to Plan 05.x or later.
- **Risk forecast UI.** Spec §11.2 shows a `weekday × time-bucket` heat grid. Standalone screen, or a card inside InsightsView? Recommendation: card inside Insights, with a "see all" tap that expands to a full screen.
- **`note` field upgrade.** If we add a `DayNote` entity later, we'll need a migration. Probably defer to whenever notes need to do more (multiple notes per day, tags, etc.).

## File map (Plan 04 additions)

```
Packages/HabitMapCore/Sources/HabitMapCore/
├── Services/
│   └── StatsService.swift                  # @MainActor — streak + consistency math
└── Components/
    ├── FilterChip.swift                    # pill button (selected / unselected)
    ├── StreakCard.swift                    # 30D% / STREAK / BEST display
    └── YearGrid.swift                      # 365-cell heat map (20×19)

Apps/iOS/HabitMap/
├── HabitMapApp.swift                       # (modified) RootView routes tabs
├── Screens/
│   ├── ComingSoonView.swift                # placeholder for STATS, SETUP
│   ├── Today/
│   │   ├── TabBar.swift                    # (modified) onSelect callback
│   │   └── TodayView.swift                 # (modified) inline TabBar removed
│   └── Map/
│       ├── MapView.swift                   # heat map screen
│       └── DayDetailSheet.swift            # day's habits + journal note

Apps/iOS/HabitMapUITests/
└── MapNavigationUITests.swift              # tap MAP → header visible
```
