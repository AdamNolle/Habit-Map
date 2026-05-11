# Plan 05 — Insights + Risk Forecast → Plan 06 handoff

## What ships

STATS tab is live. Tapping it opens `InsightsView`:

- **4 insight algorithms** computed by `InsightsEngine`:
  - **Strongest day-of-week** (WIN) — 80%+ completion rate on any weekday with ≥ 4 occurrences
  - **Idle habit** (RISK) — ≥ 7 days since last log with prior activity; at 14+ days suggests pausing
  - **Stacking** (SUGGEST) — Jaccard co-occurrence ≥ 70% between any habit pair (over days where either was done)
  - **Slip window** (RISK) — `(weekday, 3h bucket)` with ≥ 50% skip rate and ≥ 4 attempts
- **`InsightCard`** — pixel-art tile with a kind-colored badge (`win` green / `risk` red / `suggest` blue) and habit-accent border.
- **Risk forecast card** — 7×8 heatmap of weekday × 3h bucket. Cells colored from `noData` gray through `completed4` (best) → `danger` (worst). Tap to open a full-screen `RiskExpandedView` with a larger heatmap + top-3 risk windows list.
- **`RiskForecastEngine`** — produces the matrix plus a sorted top-risks array (only `warn` / `danger` levels qualify).

## Test coverage

**117 tests pass** (111 unit/snapshot + 6 UI). Plan 05 added:

| Suite | Count | Type |
|---|---:|---|
| **`InsightsEngineTests`** | 8 | unit |
| **`RiskForecastEngineTests`** | 4 | unit |
| **`InsightCardSnapshotTests`** | 3 | snapshot |
| **`RiskHeatmapSnapshotTests`** | 2 | snapshot |
| **`InsightsNavigationUITests`** | 1 | UI |

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

## Deviations from the plan

1. **Stacking algorithm uses Jaccard, not "both scheduled" denominator.** The plan originally tracked `coDays = both-scheduled-days` and `rate = both-done / coDays`. With sparse data (10 of 30 days done) that produced 33% — well below the 70% threshold even when the habits perfectly co-occurred. Switched to Jaccard: `rate = both-done / either-done`. Now two habits done on the same 10 days score 100%. Matches the spec's intent ("co-occurrence rate") and fires the suggestion correctly.
2. **`!` and `?` badge glyphs use the `PixelFont.fallback` block.** Adding real glyphs is a 5-line change but felt outside the plan's scope. Polish candidate.
3. **`InsightsEngine.bucketIndex(for:cal:)` and `.weekdayName` are `public static`** so `RiskForecastEngine` and `RiskExpandedView` can reuse them without duplication.
4. **`InsightsView` constructs `InsightsEngine` and `RiskForecastEngine` inline** instead of via environment. Both are stateless; no value in injecting. Future versions that cache results may want to hoist them.
5. **`InsightsView` recomputes insights + forecast on every body access.** That's O(habits × 30 days) — fine for dozens of habits, would re-evaluate if the user accumulates 100+ habits. Caching ranks as a Plan 11 perf-polish item.

## Known limitations (lands later)

- **Reminder-impact insight not implemented.** Needs a model field tracking when a reminder was set (or its history). Deferred to a later plan.
- **Phase-graduation insight not implemented.** Needs explicit "this is a 21-day kickstart" goal flagging — model + UI both missing.
- **Seasonal-dip insight not implemented.** Needs ≥ 1 year of completion history; not actionable for v1.
- **Empty state on Insights** — when the user has < 4 occurrences of anything (brand-new habits, brand-new install), the page just shows the empty-state copy. The risk heatmap shows all `noData` gray. Both behaviors are correct but feel sparse; might want an onboarding hint here.
- **CloudKit still off**, BGAppRefreshTask still registered but only fires on real devices.

## Open questions for Plan 06 (Notifications + Settings)

- **Notification scheduling implementation.** `UNUserNotificationCenter` requires us to schedule each habit's `reminderTime` individually. Should we batch reschedule on every `Habit` change, or use a single coordinator that listens for SwiftData changes? Recommendation: batch reschedule via a `NotificationScheduler` service that observes `HabitRepository`. Cheap on N habits.
- **Banned-phrases enforcement.** Spec §14.2 requires copy not to contain `broken`, `failed`, `missed`, `you didn't`, `streak lost`, `DON'T`. Static guard at copy-emit time, or test-only? Recommendation: a `NotificationCopy.assertSafe(_:)` runtime guard in DEBUG plus a unit-test sweep.
- **Settings layout.** Spec §15 lists 6 sections (Forgiveness, Notifications, Pages, Data·Sync, Danger Zone, About). Single `Form`-based screen or pixel-art-styled custom layout matching the rest of the app? Recommendation: pixel-art-styled custom layout for consistency; `Form` would feel out of place.
- **Reset Data flow.** Spec §15 Danger Zone says: scope picker → "type RESET" → confirm with auto-export + 30-day iCloud snapshot. The iCloud snapshot piece needs CloudKit on; defer the snapshot half and ship the in-DB reset for Plan 06.

## File map (Plan 05 additions)

```
Packages/HabitMapCore/Sources/HabitMapCore/
├── Models/
│   ├── Insight.swift                       # kind + title + body + habit ref
│   └── RiskForecast.swift                  # matrix + top-3 risk windows
├── Services/
│   ├── InsightsEngine.swift                # @MainActor — 4 algorithms
│   └── RiskForecastEngine.swift            # @MainActor — 7×8 matrix builder
└── Components/
    ├── InsightCard.swift                   # pixel-art tile
    └── RiskHeatmap.swift                   # 7×8 weekday × bucket grid

Apps/iOS/HabitMap/
├── HabitMapApp.swift                       # (modified) STATS → InsightsView
└── Screens/Insights/
    ├── InsightsView.swift                  # cards + risk card
    └── RiskExpandedView.swift              # full-screen heatmap + top windows

Apps/iOS/HabitMapUITests/
└── InsightsNavigationUITests.swift         # tap STATS → INSIGHTS header visible
```
