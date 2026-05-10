# Plan 01 — Foundation → Plan 02 handoff

## What ships

End-to-end iOS 17+ app delivering a vertical slice of Habit Map:

- **Project bootstrap:** XcodeGen `project.yml` + in-repo `HabitMapCore` SwiftPM package, `.xcodeproj` committed for stability
- **Persistence:** SwiftData models (`HabitPage`, `Habit`, `HabitCompletion`, `UserSettings`), CloudKit-ready (currently off; flip on once team ID configured)
- **Design system:** color hex parser, `DesignTokens` palette, 3×5 `PixelText`, 5 `PixelIcon`s (home / grid / plus / chart / gear), `HabitCell` with 8 levels + today outline, `PixelRing` with procedural 12-segment data
- **Today screen:** dark page with pixel-art `HEALTH` title, master heatmap card, `DRINK WATER` habit row with mini-heatmap, tappable 44pt today cell, page dots, 4-icon tab bar
- **Seed data:** Demo HEALTH page with DRINK WATER (manualMultiple ×4) and 30 days of random completion history

## Test coverage

46 tests across the suite, all green:

| Suite | Count | Type |
|---|---:|---|
| `ColorHexTests` | 6 | unit |
| `PixelFontSnapshotTests` | 4 | snapshot + unit |
| `PixelIconSnapshotTests` | 6 | snapshot |
| `HabitCellSnapshotTests` | 11 | snapshot + unit |
| `PixelRingSnapshotTests` | 7 | snapshot + unit |
| `HabitModelTests` | 7 | SwiftData unit |
| `RecoveryRateTests` | 3 | SwiftData unit |
| `PlaceholderTests` | 1 | smoke |
| `TodayFlowUITests` | 1 | UI |

Snapshot baselines committed under `__Snapshots__/` so the suite is deterministic across machines.

Run from CLI:
```
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

## Known deviations from the original spec

1. **Multiplatform target collapsed to iOS-only for Foundation.** WatchOS, iPadOS-specific, and Widget targets land in Plans 07–09. The shared core package is already structured to import cleanly from all of them.
2. **`PersistenceController.makeContainer(enableCloudKit: false)` in `HabitMapApp.swift`.** CloudKit is wired but disabled because the team ID is the placeholder `DEVTEAM`. Flip the flag in Plan 02 once a real Apple Developer team ID lands in `project.yml`.
3. **`@Attribute(.unique)` removed from model id fields.** SwiftData + CloudKit explicitly forbids explicit uniqueness constraints — record IDs serve that role on the CloudKit side. UUID natural uniqueness is preserved at the Swift level.
4. **One-to-many relationships are optional arrays (`[Habit]?`).** Required by SwiftData + CloudKit schema validation. Helpers like `MasterHeatmapCard.combinedLevel` and `PageContentView`'s ForEach unwrap with `?? []`.
5. **Today-outline uses `strokeBorder` not `stroke + padding(-2)`.** The original spec drew the outline 2px outside the cell; that approach was clipped by `drawingGroup()`. `strokeBorder` paints inside the cell bounds and looks equally clean.
6. **Icon set is 5 of 15.** Foundation only needed home / grid / plus / chart / gear for the tab bar. The other 10 (back / search / more / cloud / trash / edit / check / bell / shield / grip) land in plans that use them.
7. **`UISupportedInterfaceOrientations` is portrait-only.** Spec is silent on this; iPad rotation lands with iPad layouts in Plan 09.
8. **No animations on cell fill yet.** Spec §4 mentions haptics on milestone; light haptics are wired in tap, medium-on-p100 lands in Plan 02 or with the haptics polish later.

## Open questions for Plan 02

- **Habit creation UX:** single-screen modal or 3-step wizard (emoji → schedule → reminder)?
- **Page reorder UX:** native `List.onMove` inside a long-press mode, or a fully-custom drag interaction matching the prototype's grid-rearrangement feel?
- **CloudKit cutover:** wait until a real Developer team ID is wired (Plan 02 prereq), or build the feature behind a feature flag and ship in Plan 04?
- **Light mode:** Foundation forces dark via `.preferredColorScheme(.dark)`. Spec §21 calls for light/dark/auto. Decide if light mode is Plan 06 (Settings) or Plan 10 (Polish).

## File map for handoff

```
Habit-Map/
├── project.yml                              # XcodeGen manifest
├── HabitMap.xcodeproj/                      # generated, committed
├── Apps/iOS/HabitMap/
│   ├── HabitMapApp.swift                    # @main, model container
│   ├── HabitMap.entitlements                # CloudKit
│   └── Screens/Today/                       # TodayView, HeaderView,
│                                            # PageContentView, HabitRow,
│                                            # TabBar
├── Apps/iOS/HabitMapUITests/
│   └── TodayFlowUITests.swift
└── Packages/HabitMapCore/
    ├── Package.swift
    └── Sources/HabitMapCore/
        ├── DesignSystem/                    # ColorHex, DesignTokens,
        │                                    # PixelFont(+Glyphs),
        │                                    # PixelIcons(+Data)
        ├── Models/                          # Habit*, UserSettings,
        │                                    # CellLevel, HabitType,
        │                                    # HealthMetric, CompletionSource
        ├── Components/                      # HabitCell, PixelRing,
        │                                    # PageDots, MiniHeatmap,
        │                                    # MasterHeatmapCard
        └── Persistence/                     # PersistenceController, SeedData
```
