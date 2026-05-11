# Plan 03 — HealthKit Integration → Plan 04 handoff

## What ships

The wizard now offers `AUTO-FILL FROM HEALTH` as a fourth habit type. Users can pick from 8 metrics — steps, workouts, mindful minutes, sleep, stand hours, active energy, hydration, distance — and a goal value. Permission is requested lazily: only when the user taps the first `.autoHealth` habit row.

- **`HealthKitProviding` protocol** wraps `HKHealthStore` so the orchestrator is unit-testable with a fake.
- **`HealthKitService`** queries `HKStatisticsQuery` for cumulative quantities, `HKSampleQuery` for workouts/mindful/sleep duration. No writes back to Health (read-only, per spec §24).
- **`HealthSyncService`** walks every active `.autoHealth` habit and upserts a `HabitCompletion` with `source: .health`.
- **Foreground sync** on app launch and scene-becomes-active via `RootView` + `@Environment(\.scenePhase)`.
- **Background refresh** via `.backgroundTask(.appRefresh)` with a 15-minute minimum interval; the handler reschedules itself.
- **Auth-aware UI:** habit rows show `TAP TO AUTHORIZE` → permission sheet → progress, or `SWITCH TO MANUAL?` after a second denial (which auto-converts the habit to `.manualOnce`).
- **iPad-safe:** the wizard hides `AUTO-FILL FROM HEALTH` when `HKHealthStore.isHealthDataAvailable()` returns false.

## Test coverage

83 tests total (79 unit/snapshot + 4 UI), all green:

| Suite | Count | Status |
|---|---:|---|
| Plan 01 tests (Color, PixelFont, PixelIcon, HabitCell, PixelRing, Models, Recovery) | 45 | unchanged |
| Plan 02 tests (PixelButton, PixelToggle, FAB, AccentSwatch, EmojiPicker, WeekdayPicker, HabitRepository) | 25 | unchanged |
| **`HealthKitServiceTests`** | 4 | new — static mappings + isAvailable |
| **`HealthSyncServiceTests`** | 5 | new — happy path, update, skip, lastSyncedAt, error |
| `TodayFlowUITests` | 1 | unchanged |
| `PageCRUDUITests` | 1 | unchanged |
| `HabitWizardUITests` | 1 | unchanged |
| **`AutoHealthWizardUITests`** | 1 | new — reaches AUTO-FILL FROM HEALTH and picks STEPS |

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

## Deviations from the plan

1. **`HealthKitService` and `MockHealthKitProvider` are `@unchecked Sendable`** (not pure `Sendable`). `HKHealthStore` itself isn't `Sendable` and the mock's mutable state is fine to access serially. With `SWIFT_STRICT_CONCURRENCY: complete` set in `project.yml`, this was the minimal-change path.
2. **`HealthSyncService` deduplicates by *active* page only.** Archived pages and paused habits are skipped, matching the spec's "don't sync paused/archived" expectation.
3. **`HabitRow` transitions to `.manualOnce` on second denial** rather than offering an explicit settings toggle. Net effect: the user keeps tracking; the metric vanishes from the row. If they want to re-enable, they re-create the habit via the wizard.
4. **`HealthAuthState.denied(timesDenied:)` increments locally on each refusal**, not via SwiftData persistence. So a cold launch resets the counter to 0. That's acceptable for v1 — the user just gets another chance to authorize.
5. **`BGTaskScheduler` registration is via `.backgroundTask(.appRefresh)` scene modifier** instead of the legacy `BGTaskScheduler.shared.register(forTaskWithIdentifier:)`. Requires iOS 17+ (which we target). The handler reschedules itself, so once `scheduleNextRefresh()` runs after the first app launch, the chain self-sustains.
6. **Step 3 of the wizard still shows the REMINDER picker for `.autoHealth` habits.** That's intentional; users may want a "did you hit your step goal?" reminder. Notifications aren't wired (Plan 06).
7. **No `MockHealthKitProvider` injection point in the production app.** The `HabitMapApp.init` hardcodes `HealthKitService()`. For SwiftUI previews you can manually construct a `HealthSyncService(provider: MockHealthKitProvider(...), repository: ...)` in `#Preview` blocks.

## Known limitations (lands in later plans)

- **Simulator has no health data by default.** On a real device with active workouts/steps, values populate. On the simulator they're 0 after permission is granted. The wizard, permission sheet, and the sync pipeline all work — just no live data to display. Test on a real device for end-to-end validation.
- **Sleep handling counts in-bed + asleep variants** as a single "sleep minutes" total. Some users may want only "asleep" categories. Refinement candidate for Plan 04 or later.
- **Heart rate metric is in the picker** but its goal semantics are unclear (resting? average? max?). Currently treated as cumulative-sum which is wrong. Worth either removing from the picker until Plan 04 has a heart-rate-aware metric type, or adding a "type of measurement" picker.
- **No retry on transient HealthKit query errors.** `HealthSyncService.syncHabit` silently swallows. A polished version would distinguish transient (retry once) from permanent (skip).
- **Background task identifier is hardcoded** to `com.adam.habitmap.health-refresh`. When the bundle ID changes, this needs to change too.
- **CloudKit still off** — pending a real Apple Developer team ID.

## Open questions for Plan 04

- **Heat Map (year) screen scope.** Spec §10 shows a 365-cell grid with filter chips, streak card, day-tap → bottom-sheet day detail. Should the bottom-sheet stay in Plan 04 or split into its own plan with the journaling UI?
- **Filter behavior.** Should filter chips be additive (multi-select) or single-select? Spec is ambiguous. My recommendation: single-select with an explicit "All" chip.
- **Cell tap on year view.** Spec §10.2 says tap → day detail. Long-press → journal modal. Should the journal be a separate modal or a section in the day detail? My recommendation: section in day detail (one screen, less navigation).
- **Insights navigation.** The Insights screen (Plan 05) sits between Map and Stats. Should the existing TabBar's `STATS` route to Insights, or should we add a 5th tab? Spec §1.3 has 4 tabs. My recommendation: keep 4 tabs, route STATS → Insights, and surface streak summary as a card inside Map.

## File map (Plan 03 additions)

```
Packages/HabitMapCore/Sources/HabitMapCore/
├── Models/
│   └── HealthAuthState.swift               # auth state enum
└── Services/
    ├── HealthKitProviding.swift            # protocol + error type
    ├── HealthKitService.swift              # HKHealthStore wrapper
    ├── MockHealthKitProvider.swift         # test + preview fake
    └── HealthSyncService.swift             # @MainActor orchestrator

Apps/iOS/HabitMap/
├── Screens/Habit/
│   └── MetricPickerView.swift              # 8-metric grid + goal stepper
└── HabitMapApp.swift                       # (modified) injects HealthSyncService,
                                            # registers background refresh

project.yml                                  # (modified) HealthKit entitlement,
                                            # BGTaskSchedulerPermittedIdentifiers
```
