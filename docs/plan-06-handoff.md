# Plan 06 — Notifications + Settings + Reset Data → Plan 07 handoff

## What ships

SETUP tab is live. Tapping it opens `SettingsView` (no more `ComingSoonView`). Notifications work end-to-end on a real device; the simulator supports scheduling but won't deliver banners outside an active session.

- **Pixel-art `SettingsView`** with all 6 spec sections (Forgiveness · Notifications · Pages · Data·Sync · Danger Zone · About).
- **`NotificationCopy`** with gentle + direct tone variants, daily-reminder / weekly-reflection / per-habit copy, and a `DEBUG`-only `assertSafe(_:)` guard that crashes if a gentle string ever contains a banned phrase (`broken`, `failed`, `missed`, `you didn't`, `streak lost`, `don't`).
- **`NotificationScheduling`** protocol + production `NotificationScheduler` (UN backed) + `MockNotificationScheduler` for tests.
- **`NotificationCoordinator`** owns scheduling lifecycle: requests permission lazily when SETUP tab is first tapped, cancels-all and re-schedules whenever `UserSettings` change, subscribes to `HabitRepository.onHabitChanged` for per-habit reminders, and acts as `UNUserNotificationCenterDelegate` to route notification taps back to Today.
- **`UserSettings.fetchOrCreate(in:)`** singleton helper. `HabitRepository.userSettings()` exposes it; `HabitRepository.deleteAll(scope:)` handles 3-step Reset Data (archived only / everything).
- **`CalmModeBanner`** — pixel-art orange banner with "EASE UP / Want to pause one habit? Less can be more right now." shown above the master heatmap when 30-day consistency drops below `calmModeThreshold`. Dismissible per-day via `UserDefaults` key.
- **Default page picker** — Settings → Pages → "DEFAULT PAGE" Picker. `TodayView` respects `UserSettings.defaultPageId` on launch.
- **Haptics toggle** — `HabitRow.handleTap` reads `UserSettings.hapticsEnabled` before firing `UIImpactFeedbackGenerator`.
- **Notification tap handler** — `UNUserNotificationCenterDelegate` posts a `Notification.Name.habitMapNotificationTapped` event; `RootView` switches to Today on receipt.
- **3-step Reset Data** — scope picker → "type RESET" textfield → confirm. In-DB wipe only (iCloud snapshot deferred to CloudKit cutover).

## Test coverage

**140 tests pass** (133 unit/snapshot + 7 UI). Plan 06 added:

| Suite | Count | Type |
|---|---:|---|
| **`NotificationCopyTests`** | 9 | unit |
| **`NotificationSchedulerTests`** | 6 | unit |
| **`UserSettingsSingletonTests`** | 6 | unit + integration |
| **`CalmModeBannerSnapshotTests`** | 1 | snapshot |
| **`SettingsNavigationUITests`** | 1 | UI |

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

## Deviations from the plan

1. **`NotificationCoordinator` lives in the iOS app target, not the package.** It bridges `UNUserNotificationCenter` + SwiftData + the wizard's per-habit `reminderTime`, so it has too many app-side dependencies to live in the framework. The `NotificationScheduling` protocol + `NotificationScheduler` impl + mock all stay in `HabitMapCore` and are reused.
2. **`SettingsView` uses a child `SettingsBody` view with `@Bindable var settings: UserSettings`** instead of binding directly on the parent. SwiftUI's `@Bindable` needs an existing record, so the parent fetches once in `.task` then unwraps. Empty state shows a brief `ProgressView`.
3. **`UserSettings.defaultPageId` picker uses the Picker's tag system on `UUID?`** so the default-page picker can show "no preference" → first page implicitly. Falls back gracefully if the chosen page was archived/deleted.
4. **`CalmModeBanner` dismissal persists via `UserDefaults` keyed by today's date.** Simpler than adding a model field; auto-resets the next day, which is the desired behavior.
5. **Reset Data scope simplified to `archivedOnly` / `everything`.** The spec also lists "current page" as a scope; deferred — it's tricky to surface from Settings without knowing which page is current, and is a small refactor away.
6. **No `aps-environment` entitlement added.** Local notifications (which is all we use — `UNCalendarNotificationTrigger`) don't require the APNs entitlement. Saves us from needing a real APNs cert until remote push is on the table.
7. **The CalmModeBanner's badge character uses `PixelFont.fallback`** for the icon glyph — same pattern as Plan 05's InsightCard. Polish later.

## Known limitations (lands later)

- **Risk alerts** — `UserSettings.riskAlertsEnabled` toggle exists in Settings but no scheduling logic. Needs `RiskForecastEngine` to predict 6h-ahead windows and feed them to the scheduler. Deferred to a polish plan.
- **CSV export / import** — shown as disabled "(SOON)" rows in DATA·SYNC.
- **30-day iCloud snapshot before reset** — waits for CloudKit cutover.
- **APPLE HEALTH manage screen** — disabled row in DATA·SYNC. HealthKit per-habit settings live on the wizard / detail view for now; a dedicated manage screen would let users revoke per-metric.
- **Snooze action on notifications** — Apple supports `UNNotificationAction`; not wired yet.
- **Notification tap habit routing** — currently routes to Today tab on any tap. Routing to the specific habit's page is straightforward (parse `parseHabitID(from:)`) and is a small follow-up.
- **CloudKit still off**, BGAppRefreshTask still registered but fires only on real devices.

## Open questions for Plan 07 (Widgets + Live Activity)

- **WidgetKit timeline cadence.** Spec §16 calls for Small / Medium / Large widgets plus 3 lock-screen families. Refresh on completion change is the right trigger, but `WidgetCenter.shared.reloadAllTimelines()` can be expensive. Recommendation: call it from `HabitRepository.onHabitChanged` (already exists from Plan 06) plus once per scene-becomes-active.
- **Live Activity scope.** Spec §17 describes Live Activities for `.autoHealth` habits in progress (e.g. "10K steps"). Should Plan 07 ship Live Activities or split them off? Recommendation: ship one Live Activity (steps) in Plan 07 as a proof-of-concept; the rest follow once Watch lands.
- **App Group entitlement.** Widgets need shared storage. Add an App Group to `project.yml` and use it for the SwiftData container's URL. Decide on the App Group identifier — `group.com.adam.habitmap` is conventional.
- **Configurable widget habit.** Small widget needs the user to pick which habit it displays. `AppIntent`-based configuration is the modern API.

## File map (Plan 06 additions)

```
Packages/HabitMapCore/Sources/HabitMapCore/
├── Services/
│   ├── NotificationCopy.swift              # tone-aware copy + assertSafe
│   ├── NotificationScheduling.swift        # protocol + value types
│   ├── NotificationScheduler.swift         # UN backed impl
│   ├── MockNotificationScheduler.swift     # tests + previews
│   └── HabitRepository.swift               # (modified) onHabitChanged callback + deleteAll
├── Models/
│   └── UserSettings+Singleton.swift        # fetchOrCreate helper
└── Components/
    └── CalmModeBanner.swift                # ease-up banner

Apps/iOS/HabitMap/
├── HabitMapApp.swift                       # (modified) NotificationCoordinator + UN delegate
└── Screens/Settings/
    ├── SettingsView.swift                  # 6 sections + reset alert chain
    └── AboutSection.swift

Apps/iOS/HabitMap/Screens/Today/
├── HabitRow.swift                          # (modified) haptics gated on settings
├── TodayView.swift                         # (modified) respects defaultPageId
└── PageContentView.swift                   # (modified) renders CalmModeBanner

Apps/iOS/HabitMapUITests/
└── SettingsNavigationUITests.swift         # tap SETUP → SETTINGS header
```
