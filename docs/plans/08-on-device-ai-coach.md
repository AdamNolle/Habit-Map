# Habit Map — Plan 08: On-Device AI Coach

> Replaces the original Plan 08 (Widgets + Live Activity), which is now Plan 09. The user's first-run testing call surfaced a stronger product request: a coach that learns their personal habit patterns and explains *when* and *why* they slip — without sending data off-device.

## Context

The app already has the raw machinery: completion history, `StatsService` (streaks + consistency), `InsightsEngine` (4 algorithms detecting patterns), `RiskForecastEngine` (weekday × time-bucket skip rates). What's missing is the **synthesis layer** — turning those features into a coherent, personalized story the user can act on, and (ideally) using an actual on-device language model to make the coaching feel human.

This plan ships two layers in one feature:

1. **Slip-detection engine** — a deterministic Swift pipeline that computes feature vectors from the user's recent completion history (weekday performance, time-of-day risk, idle days, pair correlations, streak-break antecedents, recovery time). Works on iOS 17+. Pure functions, fully testable. No ML model needed for the math — just statistics over the user's own data.

2. **Coaching layer** — converts the feature vector into natural-language narrative. Two implementations, chosen at runtime:
   - **`FoundationModels` framework on iOS 26+** — Apple's on-device LLM (Apple Intelligence). Gets us real conversational quality with zero network calls, private by design.
   - **Rule-based templated fallback on iOS 17–25** — composes paragraphs from sentence templates filled with the feature-vector data. Less natural but works everywhere.

The coach lives as a new section at the top of `InsightsView` and (later) as a dedicated chat-style screen.

**Privacy:** zero off-device transmission. No analytics. No third-party LLM API. The on-device Foundation Models framework runs entirely on the Neural Engine. The fallback path is pure-Swift string composition.

---

## File Structure (new additions)

```
Packages/HabitMapCore/
  Sources/HabitMapCore/
    Services/
      SlipFeatureExtractor.swift           # pulls features from habits + completions
      HabitCoachEngine.swift               # protocol + dispatcher (FM or rules)
      FoundationModelsCoach.swift          # iOS 26+ Apple Intelligence impl
      RuleBasedCoach.swift                 # iOS 17+ templated fallback
    Models/
      SlipFeatures.swift                   # value type — what the coach reasons about
      CoachInsight.swift                   # output: title + paragraph + suggested action
  Tests/HabitMapCoreTests/
    SlipFeatureExtractorTests.swift        # feature extraction correctness
    RuleBasedCoachTests.swift              # template output sanity + banned-phrase guard

Apps/iOS/HabitMap/
  Screens/
    Insights/
      InsightsView.swift                   # (modified) add CoachSection at top
      CoachSection.swift                   # new component — renders the coach paragraph + refresh
      CoachChatView.swift                  # tap-to-expand — free-form Q&A using Foundation Models
```

---

## Task list

### Task 1: `SlipFeatures` model + `SlipFeatureExtractor`

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Models/SlipFeatures.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/SlipFeatureExtractor.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/SlipFeatureExtractorTests.swift`

A `SlipFeatures` struct captures everything the coach needs about *one user's* recent behavior:

```swift
public struct SlipFeatures: Sendable, Equatable {
    public let windowDays: Int                // typically 30
    public let totalScheduled: Int            // days × habits expected
    public let totalCompleted: Int            // actually done
    public let consistencyPct: Double         // completed / scheduled

    public let perHabit: [HabitFeatures]
    public let weekdayCompletion: [Double]    // 7 entries Mon..Sun, 0..1
    public let topSlipWindows: [SlipWindow]   // (weekday, hour bucket, skip rate)
    public let idleHabits: [String]           // habit names not logged in 7+ days
    public let strongPairs: [HabitPair]       // (a, b, co-occurrence rate)
    public let recoveryTime: Double           // avg days to bounce back after a miss
    public let streakBreakSignals: [String]   // e.g. "Sunday evenings", "after a workout day"
}

public struct HabitFeatures: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let typeRaw: String
    public let consistency30d: Double
    public let bestWeekday: Int?
    public let worstWeekday: Int?
    public let daysSinceLastLog: Int
}

public struct SlipWindow: Sendable, Equatable {
    public let weekday: Int            // 0=Mon ... 6=Sun
    public let bucketHour: Int         // 6, 9, 12, 15, 18, 21, 0, 3
    public let skipRate: Double
    public let attempts: Int
}

public struct HabitPair: Sendable, Equatable {
    public let a: String
    public let b: String
    public let coOccurrenceRate: Double
}
```

`SlipFeatureExtractor` reuses existing engines:
- Calls `StatsService.consistency`, `RiskForecastEngine.forecast`, `InsightsEngine.idleHabits` and `stackingSuggestions`
- Adds: per-weekday completion rate (`weekdayCompletion`), recovery time after a miss, streak-break signals

**Tests:** ~6 tests asserting on fixture habit data that features come out correctly (zero days, single habit, two pairs with high overlap, etc.).

---

### Task 2: `CoachInsight` model + `HabitCoachEngine` protocol

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Models/CoachInsight.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/HabitCoachEngine.swift`

```swift
public struct CoachInsight: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let headline: String          // 1-line summary, e.g. "Saturdays at 9 PM are your weak spot"
    public let paragraph: String         // 2-4 sentences explaining what & why
    public let suggestion: String?       // optional concrete action, e.g. "Try moving your run earlier on Saturdays"
    public let highlightedHabitID: UUID? // optional
}

public protocol HabitCoachEngine: Sendable {
    func coach(features: SlipFeatures) async throws -> CoachInsight
    func answer(question: String, features: SlipFeatures) async throws -> String
}
```

A `HabitCoachFactory` static helper picks the best implementation at runtime:
- iOS 26+ with Foundation Models available → `FoundationModelsCoach`
- Else → `RuleBasedCoach`

---

### Task 3: `RuleBasedCoach` (iOS 17+ fallback, always available)

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/RuleBasedCoach.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/RuleBasedCoachTests.swift`

Composes coaching insights from sentence templates filled with feature data. The algorithm picks the **most actionable** insight to lead with by priority:

1. If `topSlipWindows.first.skipRate >= 0.5` → lead with the slip window: "Saturday evenings around 6 PM are when you tend to skip — 4 of the last 6 attempts didn't happen."
2. Else if `idleHabits.count > 0` → lead with the idle habit: "DRINK WATER has been quiet for 11 days — want to pause it for now?"
3. Else if `strongPairs.first.coOccurrenceRate >= 0.7` → lead with stacking: "READ and STRETCH almost always happen together (89%). Pair them in your morning routine."
4. Else if `consistencyPct < 0.4` → calm-mode style: "Last 30 days landed around 32%. That's a signal to ease up, not push harder."
5. Else if `weekdayCompletion.max - min > 0.4` → weekday strength: "Tuesdays are where you shine (94%) — Sundays are your weakest (38%)."
6. Default → win celebration: "Your last 30 days look steady. Nothing to fix; keep showing up."

For each lead, a paragraph and an optional suggested action are composed from a small library of variants per category. All copy passes through `NotificationCopy.assertSafe(_:tone:)` (gentle tone) to keep language non-punishing.

**`answer(question:features:)`** in the rule-based coach is intentionally minimal — keyword routing into one of the same templates above ("when am i slipping?" → slip window response). For real conversation, Foundation Models is required.

**Tests:** ~6 tests asserting:
- Different feature configurations produce different headlines
- Gentle copy never contains banned phrases
- Empty features (brand-new install) produces sensible default
- Slip-window headline references the correct weekday + bucket

---

### Task 4: `FoundationModelsCoach` (iOS 26+ Apple Intelligence)

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/FoundationModelsCoach.swift`

Wraps Apple's `FoundationModels` framework. Available on iOS 26+. Sends the `SlipFeatures` value as structured JSON in a system prompt, asks the model to respond with a `CoachInsight`-shaped JSON, parses it.

```swift
@available(iOS 26.0, *)
public final class FoundationModelsCoach: HabitCoachEngine {
    private let session: LanguageModelSession

    public init() throws {
        // Construct session with system prompt that bounds the coach's role.
        self.session = LanguageModelSession(instructions: """
        You are a non-punishing habit coach. The user shares their recent
        habit-tracking data; you respond in 2-3 sentences with the single most
        useful observation and (if relevant) one concrete suggested action.
        Never use words like "broken", "failed", "missed", "you didn't".
        Speak in second person, warm but direct. Output JSON matching
        CoachInsight: { headline, paragraph, suggestion?, highlightedHabitID? }.
        """)
    }

    public func coach(features: SlipFeatures) async throws -> CoachInsight {
        let json = try JSONEncoder().encode(features)
        let prompt = "Analyze this habit data and produce one CoachInsight.\n" +
                     String(data: json, encoding: .utf8)!
        let response = try await session.respond(to: prompt, generating: CoachInsight.self)
        return response.content
    }

    public func answer(question: String, features: SlipFeatures) async throws -> String {
        let json = try JSONEncoder().encode(features)
        let prompt = "Context: \(String(data: json, encoding: .utf8)!)\n\nQuestion: \(question)"
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
```

`CoachInsight` is annotated `@Generable` for the framework's structured output.

**No tests** — Foundation Models can't be reliably mocked in unit tests (the framework requires a real Neural Engine model). Manual smoke on iOS 26 device only.

---

### Task 5: `HabitCoachFactory` + dispatcher

**File:** Append to `HabitCoachEngine.swift`:

```swift
public enum HabitCoachFactory {
    @MainActor
    public static func make() -> any HabitCoachEngine {
        if #available(iOS 26.0, *) {
            // Foundation Models is gated on device + model availability.
            if FoundationModelsCoach.isAvailable {
                return (try? FoundationModelsCoach()) ?? RuleBasedCoach()
            }
        }
        return RuleBasedCoach()
    }
}
```

`FoundationModelsCoach.isAvailable` static checks Apple Intelligence eligibility (device supports it + user has enabled it).

---

### Task 6: `CoachSection` component + InsightsView integration

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Insights/CoachSection.swift`
- Modify: `Apps/iOS/HabitMap/Screens/Insights/InsightsView.swift`

`CoachSection` renders at the top of the Insights screen above the existing insight cards:

```
┌──────────────────────────────────────────┐
│ ●  YOUR COACH                  REFRESH ↻ │
│                                          │
│ Saturday evenings around 6 PM are when   │
│ you tend to skip. 4 of the last 6        │
│ attempts didn't happen.                  │
│                                          │
│ ▸ Try moving your run earlier on Saturdays│
│                                          │
│                              ASK MORE → │
└──────────────────────────────────────────┘
```

- Refresh button recomputes features + regenerates the insight.
- "Ask more →" opens `CoachChatView`.
- Loading state shows pulsing pixel-art animation while the model thinks.

The coach is fetched in an `@MainActor Task` on first appearance, cached for the session.

---

### Task 7: `CoachChatView` — free-form Q&A (iOS 26+ only — gated UI)

**File:** Create `Apps/iOS/HabitMap/Screens/Insights/CoachChatView.swift`

A simple chat interface: scrolling list of messages + text field at the bottom. Each user message sends `engine.answer(question:features:)` and appends the response. On iOS 17-25 (rule-based coach), this screen shows a banner: "Free-form questions need Apple Intelligence (iOS 26+). Try the suggested actions instead."

---

### Task 8: Tests + verification + handoff

- Run full test suite. Ensure existing tests still pass + new `SlipFeatureExtractorTests` (6) and `RuleBasedCoachTests` (6) pass.
- Manual smoke on iOS 18.5 simulator (rule-based path): InsightsView shows COACH section with a deterministic paragraph that updates as you log/skip habits.
- If a real iPhone with iOS 26 + Apple Intelligence is available, manual smoke the Foundation Models path.
- Write `docs/plan-08-handoff.md`. Push.

---

## Verification

After all 8 tasks ship:

1. Open STATS tab. The COACH section appears above the existing INSIGHTS heading.
2. Log a habit completion / mark a slip. Tap REFRESH on the coach card. The headline updates.
3. With seeded data (~30 days, one habit), coach lead falls into one of the 6 rule-based categories.
4. Tap "ASK MORE →". On iOS 17-25 → banner explains the limitation. On iOS 26+ Apple Intelligence devices → real conversational interface.
5. Full test suite: `xcodebuild test ...` green.

## Out of scope

- Cross-device personalization (would need CloudKit).
- Voice input.
- Push-driven proactive coaching ("Coach noticed you skipped Saturday again").
- Multi-language coach copy.
- Foundation Models fine-tuning.

## Why this approach

- **Privacy by default:** Apple's on-device Foundation Models means no data leaves the device. The rule-based fallback never sees anything outside the app's own SwiftData store.
- **Always works:** the deterministic fallback ensures useful coaching even on iOS 17 / non-Apple-Intelligence devices. iOS 26 users just get a noticeably richer experience.
- **Reuses existing engines:** no new pattern-detection logic; just synthesis.
- **Testable:** the feature extractor and rule-based coach are pure functions, fully covered by unit tests. The LLM layer is appropriately untested (mockable only at integration level).

## Open questions before execution

1. **Deployment-target bump?** Foundation Models needs iOS 26+. Are you comfortable bumping the deployment target later (Plan 11/Polish), or do you want to support iOS 17 as the floor permanently? My recommendation: keep iOS 17 deployment, gate Foundation Models behind `@available(iOS 26.0, *)`.
2. **Show coach to users who have < 7 days of data?** Recommendation: yes, with a "still learning your patterns" headline; no specific call-out.
3. **Should the coach be in the Today tab or Insights tab?** Currently planned for Insights. Today is also a fair home; what's your preference?

---

Once you confirm the open questions (or accept the recommendations) I'll execute this end-to-end.
