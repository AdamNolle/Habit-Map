# Plan 02 — Pages & Habits CRUD → Plan 03 handoff

## What ships

The app is now usable as a multi-page habit tracker. Users can:

- **Pages:** create, rename, recolor, drag-reorder, archive, delete (with habit migration). Pages Manager opens from the grid icon in the header.
- **Habits:** create via a 3-step wizard (name + emoji + accent → type + target → schedule + reminder), edit/archive/delete via the row's context menu or detail view, view the big `PixelRing` of today's progress.
- **FAB:** floating bottom-right plus button, tinted to the current page's accent, opens the wizard for that page.
- **Wizard:** supports `manualOnce`, `manualMultiple` (with stepper for target reps), and `inverse` habit types. Wizard accepts and persists `reminderTime` but does **not** schedule a notification yet — that lands in Plan 06.

## Test coverage

73 tests total, all green:

| Suite | Count | Notes |
|---|---:|---|
| `ColorHexTests` | 6 | Plan 01 |
| `PixelFontSnapshotTests` | 4 | Plan 01 |
| `PixelIconSnapshotTests` | 6 | Plan 01 |
| `HabitCellSnapshotTests` | 11 | Plan 01 |
| `PixelRingSnapshotTests` | 7 | Plan 01 |
| `HabitModelTests` | 7 | Plan 01 |
| `RecoveryRateTests` | 3 | Plan 01 |
| `PlaceholderTests` | 1 | smoke |
| **`PixelButtonSnapshotTests`** | 4 | new |
| **`PixelToggleSnapshotTests`** | 2 | new |
| **`FABSnapshotTests`** | 1 | new |
| **`AccentSwatchPickerSnapshotTests`** | 2 | new |
| **`EmojiPickerTests`** | 3 | new |
| **`WeekdayPickerSnapshotTests`** | 3 | new |
| **`HabitRepositoryTests`** | 10 | new — CRUD + migration |
| `TodayFlowUITests` | 1 | Plan 01 |
| **`PageCRUDUITests`** | 1 | new |
| **`HabitWizardUITests`** | 1 | new |

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

## Deviations from the plan

1. **`HabitRepository` is `@MainActor` `ObservableObject`, not a Swift actor.** Pure actors don't play well with SwiftData `ModelContext` (which is `@MainActor`-isolated) and SwiftUI's `EnvironmentObject` (which needs a class). Wrapping in `@MainActor ObservableObject` gives the same single-seam-for-side-effects benefit while staying SwiftUI-friendly.
2. **`HabitPage: Identifiable` added in `TodayView.swift`.** Needed for `.sheet(item:)` to drive the wizard. Single conformance line, no behavior change.
3. **Wizard's "AVOID" type (`.inverse`) reaches creation but can't be tapped on Today yet.** The HabitRow already supports `slipped` toggling from Plan 01, but the `.inverse` row label says "CLEAN / SLIPPED" which only changes by tapping the cell. Works fine; just noting that the UX for inverse habits is minimal.
4. **TodayView now filters archived pages from the `TabView` and `PageDots`.** Archived pages stay in the data store and reappear in the Archived section of Pages Manager.
5. **`onChange(of: pages)` selects a fallback page** if the currently-selected page is deleted or archived. Prevents a blank screen after destructive actions.

## Known limitations (lands in later plans)

- **Notifications never fire.** The `reminderTime` is stored on `Habit` but `UNUserNotificationCenter` is untouched. Plan 06 wires up notification scheduling, gentle/direct tone, and the banned-phrases guard.
- **`.autoHealth` habit type is in the model but the wizard doesn't surface it.** Plan 03 adds the HealthKit picker and metric selection.
- **Cross-page drag-to-reorder for habits is not implemented.** Within a page, reorder works via Pages Manager Edit mode (for pages). Habit-level reorder UI ships with Plan 04 (Heat Map / Detail) or Plan 10 (Polish).
- **`HabitDetailView` does not yet expose `restDayMask`.** Calendar rest days have a place in the model but no UI yet.
- **CloudKit remains off.** Same as Plan 01 — flip on once a real Apple Developer team ID replaces `DEVTEAM` in `project.yml`.

## Open questions for Plan 03

- **HealthKit permission timing.** Request on first launch (per spec §20 onboarding step 4), or on first creation of an `.autoHealth` habit? My recommendation: defer until first auto-health habit is created, so users who never link Health never see the permission sheet.
- **What happens if HealthKit auth is denied or revoked?** Show "Tap to authorize" inline on the habit row (per spec §22), or fall back to manual tap-to-log? My recommendation: inline tap-to-authorize, with a "switch to manual" affordance after the second denial.
- **Background fetch cadence.** Spec §12.2 says "every 15 min." That's the practical floor iOS allows for `BGAppRefreshTask`, and the OS may delay further. Confirm we're OK with up-to-an-hour data lag on the Today screen, with foreground refresh covering the rest.

## File map (Plan 02 additions)

```
Apps/iOS/HabitMap/
├── Components/
│   └── WizardProgressBar.swift             # 3-dot pixel progress
└── Screens/
    ├── Pages/
    │   ├── PagesManagerView.swift          # list, reorder, archive, delete
    │   ├── AddPageSheet.swift              # name + emoji + accent
    │   └── EditPageSheet.swift             # rename / recolor
    └── Habit/
        ├── AddHabitWizardView.swift        # 3-step host
        ├── AddHabitStep1View.swift         # name + emoji + accent
        ├── AddHabitStep2View.swift         # type + target reps
        ├── AddHabitStep3View.swift         # schedule + reminder
        └── HabitDetailView.swift           # PixelRing + edit + archive/delete

Apps/iOS/HabitMapUITests/
├── PageCRUDUITests.swift
└── HabitWizardUITests.swift

Packages/HabitMapCore/Sources/HabitMapCore/
├── Components/
│   ├── PixelButton.swift                   # primary / secondary / destructive
│   ├── PixelToggle.swift
│   ├── FAB.swift
│   ├── AccentSwatchPicker.swift            # 9 swatches
│   ├── EmojiPicker.swift                   # 64 curated emoji
│   └── WeekdayPicker.swift                 # MTWTFSS bitmask toggle
└── Services/
    └── HabitRepository.swift               # @MainActor ObservableObject
```
