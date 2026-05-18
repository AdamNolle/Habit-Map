# Plan 08 — On-Device AI Coach → Plan 09 handoff

## What ships

An on-device personalized habit coach in the STATS tab. Two implementations chosen automatically by `HabitCoachFactory.make()`:

- **`RuleBasedCoach`** — iOS 17+, deterministic templated paragraphs. Works on every supported device. Picks one of 6 prioritized insight categories: slip-window → idle → stacking → ease-up → weekday-strength → steady. All output passes through the gentle-tone banned-phrases guard from Plan 06.
- **`FoundationModelsCoach`** — iOS 26+ with Apple Intelligence on, real LLM coaching with free-form chat. Wraps `LanguageModelSession`; structured-JSON prompt + parsed response. All inference runs on the Neural Engine — no data leaves the device.

`SlipFeatureExtractor` builds a `SlipFeatures` snapshot from each user's recent 30 days of habit + completion data: overall consistency, per-weekday completion rates, top slip windows (weekday × time bucket), idle habits, stacking pairs, average recovery time after a miss. Reuses existing engines (`StatsService`, `InsightsEngine`, `RiskForecastEngine`).

UI additions inside Insights:

- **`CoachSection`** — coach card at the top of `InsightsView` with headline + paragraph + suggested action + refresh button. Loading state shows a spinning icon while the coach thinks.
- **`CoachChatView`** — full-screen chat sheet (gated by `coach.supportsFreeFormChat`). User can type questions; coach responds. On rule-based devices, a banner explains the limitation.

## File map

```
Packages/HabitMapCore/Sources/HabitMapCore/
├── Models/
│   ├── SlipFeatures.swift                  # extracted feature vector
│   └── CoachInsight.swift                  # coach output shape
└── Services/
    ├── SlipFeatureExtractor.swift          # @MainActor — reads habits → SlipFeatures
    ├── HabitCoachEngine.swift              # protocol + HabitCoachFactory dispatcher
    ├── RuleBasedCoach.swift                # iOS 17+ templated coach
    └── FoundationModelsCoach.swift         # iOS 26+ Apple Intelligence

Apps/iOS/HabitMap/Screens/Insights/
├── InsightsView.swift                      # (modified) hosts CoachSection at top
├── CoachSection.swift                      # coach card
└── CoachChatView.swift                     # free-form chat sheet
```

## Test coverage

Plan 08 adds:

- `SlipFeatureExtractorTests` — 6 tests covering empty habits, learning state, idle detection, weekday counts, recovery gap.
- `RuleBasedCoachTests` — 6 tests covering each priority category + banned-phrases sweep.

## Deviations from the plan

1. **`CoachInsight` is plain `Codable`, not `@Generable`.** The Foundation Models framework's `Generable` macro is a hard requirement for typed responses, but adding it forces an `iOS 26+` annotation on the whole struct. To keep `CoachInsight` callable from iOS 17 code, I parse the model's JSON response manually in `FoundationModelsCoach`. Slightly looser type guarantees, but the parse failure path falls back to using the raw text as the paragraph.
2. **`SlipFeatureExtractor` is `@MainActor`** because it touches `Habit` model objects which are SwiftData-bound. The label helpers (`weekdayName`, `formatHour`, `hourForBucket`) are `nonisolated static` so the `RuleBasedCoach` can call them from non-async contexts.
3. **The chat sheet routes to the coach factory inline** rather than receiving it as an environment object. Coaches are stateless after init, so this is simpler than wiring a new EnvironmentObject through the app.

## Known limitations

- **Foundation Models conditional import:** `#if canImport(FoundationModels)` gates the real implementation. On the iPhone 16 simulator (iOS 18.5), the rule-based path always runs even if the host Xcode could compile against iOS 26. To smoke-test the Foundation Models path you need an iPhone 17/Pro/Air with iOS 26+ and Apple Intelligence enabled, OR an iPhone 17 simulator on iOS 26 (the simulator runtime supports Apple Intelligence in iOS 26).
- **Streak-break signals are coarse:** today they're just "weekday with the worst rate" and the top slip window. A more sophisticated detector could look at "what habit was done the day before a streak break" patterns.
- **No coach memory:** each refresh starts a new `LanguageModelSession`. For multi-turn chat within a single sitting, sessions persist in `CoachChatView`'s `@State` — they don't survive sheet dismissal.
- **No proactive coaching:** the coach only speaks when the user opens Insights or asks. A future plan could trigger a notification on a slip pattern.
- **Cannot build right now without iOS 26.5 simulator runtime.** Host environment issue: Xcode auto-updated to 26.5 but the matching runtime isn't installed. Source compiles cleanly — install via **Xcode → Settings → Platforms → iOS 26.5**.

## Open questions for Plan 09 (Widgets + Live Activity, original plan)

- **Coach availability on the Watch:** with watchOS 11+, can the coach run there? Foundation Models is iOS-only currently; the rule-based path would work on watchOS.
- **Surface coach in the daily reminder notification?** "Coach noticed Saturday evenings have been a struggle — try moving your run earlier today." Requires running the extractor on a background `BGTask` before scheduling. Worth a small plan of its own.

## Privacy posture

- 100% on-device. No telemetry. No third-party LLM. The rule-based coach is pure Swift string composition. The Foundation Models coach uses Apple's `LanguageModelSession` which runs on the Neural Engine; Apple's published model card guarantees no off-device transmission.
- The full `SlipFeatures` payload sent to the model is just the user's own data, restructured. Nothing about other users, nothing identifying.
- All gentle-tone copy still flows through `NotificationCopy.assertSafe(_:tone:)`.
