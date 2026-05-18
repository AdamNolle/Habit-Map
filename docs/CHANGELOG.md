# Habit Map — Changelog

Reverse-chronological summary of shipped milestones. Detailed per-task history lives in `git log`.

## v0.9 — Apple-Design-Awards Refresh + Haptics + Test Suite (Plan 09)

- Visual identity overhaul: Instrument Serif italic headlines, Inter sans-serif body, JetBrains Mono numerics, Silkscreen pixel only for heatmap cells and PageMark.
- New components: `Display`, `Eyebrow`, `MonoNum`, `SymbolIcon`, `GlassCard`, `Pip`, `PageMark`, `DashRule`, `LavaBackground`, `IconTile`, `AppButton`, `Chip`. Refined `HabitCell` with rounded corners + isToday glow.
- Light + dark themes with tonal accent remapping. Display Mode picker in Setup.
- New `Haptics` semantic API (`selection`, `tap`, `complete`, `warn`, `success`, `failure`), gated on `UserSettings.hapticsEnabled`. Threaded through every interactive surface.
- SF Symbols replace PixelIcon for tab bar, navigation chevrons, and habit row icons.
- SwiftLint integration via Mint with pre-build phase.
- Test suite expansion: per-component snapshots in light + dark, `HapticsTests`, `ColorHexTonalTests`, `ThemeSwitchUITests`, `HapticsDisabledUITests`. Organized via `HabitMap.xctestplan`.
- Cleanup: removed `PixelIcons`, `PixelButton`, `FilterChip`, `ComingSoonView`, the deprecated `TabBar.swift` stub, and all historical plan/handoff docs.

## v0.8 — On-Device AI Coach (Plan 08)

- `SlipFeatureExtractor` builds a `SlipFeatures` vector from 30 days of completion data: weekday rates, slip windows, idle habits, pair correlations, recovery time.
- `RuleBasedCoach` (iOS 17+) picks one of 6 prioritized insight categories and writes 2-3 sentence guidance + optional action. All copy gated by `NotificationCopy.assertSafe`.
- `FoundationModelsCoach` (iOS 26+) wraps `LanguageModelSession` for on-device LLM coaching + free-form chat. Zero data leaves the Neural Engine.
- `HabitCoachFactory.make()` auto-selects the best backend.
- `CoachSection` at the top of Insights with refresh + Ask More. `CoachChatView` full-screen chat.

## v0.7 — UX Polish + Liquid Glass Refresh (Plan 07)

- Fixed PixelFont missing glyphs (`+`, `!`, `?`, `'`, etc.).
- Native `TabView` with iOS 18+ Liquid Glass treatment (replaced custom `TabBar`).
- FAB shrunk to 48pt with spring rotation. PixelButton + FilterChip get scale-on-press animations.
- Initial MonoText pass (now superseded by Plan 09 typography system).

## v0.6 — Notifications + Settings + Reset Data (Plan 06)

- `NotificationCopy` with gentle/direct tone variants + DEBUG-only banned-phrases guard.
- `NotificationScheduler` (`UNUserNotificationCenter` wrapper) + `MockNotificationScheduler` for tests.
- `NotificationCoordinator` orchestrates lifecycle, requests permission lazily, batch reschedules on settings change, schedules per-habit reminders via `HabitRepository.onHabitChanged`, routes notification taps to Today.
- Full `SettingsView` with all 6 spec sections. Default-page picker. Haptics toggle.
- 3-step Reset Data flow with in-DB wipe.
- `CalmModeBanner` on Today when 30-day consistency drops below `calmModeThreshold`.

## v0.5 — Insights + Risk Forecast (Plan 05)

- `InsightsEngine` with 4 algorithms: strongest day-of-week (WIN), idle habit (RISK), stacking (SUGGEST), time-of-day skip risk (RISK).
- `RiskForecastEngine` produces a 7×8 weekday×time-bucket matrix.
- `InsightsView` (STATS tab) with insight cards + risk heatmap card.
- `RiskExpandedView` full-screen heatmap.

## v0.4 — Heat Map (Plan 04)

- `StatsService` with streak + consistency math.
- `FilterChip`, `StreakCard`, `YearGrid` components.
- `MapView` with year heat map (365 cells) + filter chips + streak card + legend.
- `DayDetailSheet` with per-day habit status + journal note editor.
- Tab navigation refactored to native `TabView` in `RootView`.

## v0.3 — HealthKit (Plan 03)

- `HealthKitProviding` protocol + `HealthKitService` (HKHealthStore wrapper) + `MockHealthKitProvider`.
- `HealthSyncService` orchestrator. Lazy permission ask. Auth-aware HabitRow.
- 8 metrics supported. Wizard gets `AUTO-FILL FROM HEALTH` option + `MetricPickerView`.
- Background refresh via `.backgroundTask(.appRefresh)` 15-min interval.

## v0.2 — Pages + Habits CRUD (Plan 02)

- `HabitRepository` (`@MainActor ObservableObject`) for all pages/habits CRUD.
- `PagesManagerView` with reorder, archive, delete (with habit migration).
- 3-step `AddHabitWizard`: name+emoji+accent → type+target → schedule+reminder.
- `HabitDetailView` with edit/archive/delete + context menu on rows.
- Components: PixelButton, PixelToggle, FAB, EmojiPicker, AccentSwatchPicker, WeekdayPicker.

## v0.1 — Foundation (Plan 01)

- XcodeGen project + in-repo `HabitMapCore` Swift package.
- SwiftData models (`HabitPage`, `Habit`, `HabitCompletion`, `UserSettings`) with progress, cell-level, recovery-rate logic.
- Pixel-art design system: hex colors, design tokens, 3x5 PixelFont, 5 PixelIcons, `HabitCell` (8 levels), 12-segment `PixelRing`.
- Today screen with one seeded HEALTH page + DRINK WATER habit.
