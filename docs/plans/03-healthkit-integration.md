# Habit Map — Plan 03: HealthKit Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Users can create `.autoHealth` habits backed by Apple Health (steps, workouts, mindful minutes, sleep, stand hours, active energy, hydration, distance, heart rate). The app requests HealthKit permission lazily — only when a user creates their first auto-health habit. A `HealthSyncService` refreshes today's progress on app launch, on scene-become-active, and every ~15 minutes in the background via `BGAppRefreshTask`. Habit rows surface authorization state (authorized / undetermined / denied) directly, with a clean fallback to manual tap-to-log after a second denial.

**Architecture:** A `HealthKitProviding` protocol abstracts the framework so the orchestrator (`HealthSyncService`) can be unit-tested with a fake. Production uses `HealthKitService` wrapping `HKHealthStore`. The sync service walks all `.autoHealth` habits, queries each metric for the current day, and upserts a `HabitCompletion` with `source: .health`. SwiftUI scene modifiers handle background + foreground triggers.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 17+, HealthKit, BackgroundTasks. No new third-party deps.

---

## Context

Plan 02 shipped pages/habits CRUD. The wizard supports `.manualOnce`, `.manualMultiple`, and `.inverse` types. `.autoHealth` is in the data model but unreachable in the UI and not yet wired to HealthKit.

**This plan delivers:**
- Lazy permission request (no upfront ask)
- Metric picker in the wizard for `.autoHealth` habits
- Read-only HealthKit query layer (no writes, never persist raw values — only "did goal hit?" per spec §24)
- Background refresh + foreground refresh
- UI states on `HabitRow` for authorization gaps

**Out of scope** (still on the list): Heat Map screen, Day-detail journal, Insights, Risk Forecast, Notifications scheduling, Settings, Reset Data, Widgets, Live Activity, Watch app, iPad layouts, Onboarding, Themes, CloudKit cutover.

**Confirmed decisions:**
- Defer permission ask until first `.autoHealth` habit is created
- Denied → inline tap-to-authorize; after 2nd denial show "Switch to manual"
- Use `BGAppRefreshTask` with 15-min minimum interval (iOS may delay)
- iPad: `HKHealthStore.isHealthDataAvailable()` returns false; hide `.autoHealth` option there

---

## File Structure (new additions)

```
Packages/HabitMapCore/
  Sources/HabitMapCore/
    Services/
      HealthKitProviding.swift          # protocol + types
      HealthKitService.swift            # production HKHealthStore impl
      MockHealthKitProvider.swift       # in-package, used by tests + #if DEBUG
      HealthSyncService.swift           # orchestrator
    Models/
      HealthAuthState.swift             # authorized | undetermined | denied(count)
      UserSettings.swift                # (modified) add healthDeniedCount
  Tests/HabitMapCoreTests/
    HealthKitServiceTests.swift         # protocol contract tests vs mock
    HealthSyncServiceTests.swift        # orchestrator behavior tests

Apps/iOS/HabitMap/
  Screens/
    Habit/
      AddHabitStep2View.swift           # (modified) gain .autoHealth option
      MetricPickerView.swift            # 9-metric grid with HKHealthStore.isHealthDataAvailable() guard
  Screens/
    Today/
      HabitRow.swift                    # (modified) auth states + tap-to-authorize
  HabitMapApp.swift                     # (modified) inject HealthSyncService + scene modifiers
project.yml                             # (modified) add HealthKit entitlement
```

---

## Task 1: HealthKitProviding protocol + supporting types

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/HealthKitProviding.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Models/HealthAuthState.swift`

- [ ] **Step 1: Write `HealthAuthState.swift`**

```swift
public enum HealthAuthState: Equatable, Sendable {
    case unavailable          // device doesn't support HealthKit (iPad, etc.)
    case undetermined         // never asked
    case authorized
    case denied(timesDenied: Int)   // user denied at least once; track for fallback UX
}
```

- [ ] **Step 2: Write `HealthKitProviding.swift`**

```swift
import Foundation

public protocol HealthKitProviding: Sendable {
    /// True if HealthKit is available on this device (false on iPad, Mac, etc.).
    var isAvailable: Bool { get }

    /// Current authorization state. Implementations should NOT trigger UI; only read cached state.
    func authState(for metrics: Set<HealthMetric>) async -> HealthAuthState

    /// Triggers the system permission sheet. Returns the resulting state.
    @discardableResult
    func requestAuthorization(for metrics: Set<HealthMetric>) async throws -> HealthAuthState

    /// Returns the cumulative value of `metric` for the calendar day containing `date`.
    /// For workouts / mindful sessions this is a count or summed duration in seconds; for steps it's the step count;
    /// for distance it's meters; for hydration it's milliliters.
    func todayTotal(for metric: HealthMetric, on date: Date) async throws -> Double
}

public enum HealthKitError: LocalizedError {
    case unavailable
    case authorizationFailed(underlying: Error?)
    case queryFailed(underlying: Error?)

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "HealthKit is not available on this device."
        case .authorizationFailed(let err): return "Authorization failed: \(err?.localizedDescription ?? "unknown")"
        case .queryFailed(let err): return "Query failed: \(err?.localizedDescription ?? "unknown")"
        }
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
git add Packages/HabitMapCore
git commit -m "feat(health): add HealthKitProviding protocol and HealthAuthState"
```

---

## Task 2: HealthKitService — production HKHealthStore implementation

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/HealthKitService.swift`
- Modify: `project.yml` — add `com.apple.developer.healthkit` entitlement
- Modify: `Apps/iOS/HabitMap/HabitMap.entitlements` (auto-generated by XcodeGen)

- [ ] **Step 1: Add HealthKit entitlement to `project.yml`**

In the `HabitMap` target's `entitlements.properties` block, add:

```yaml
    entitlements:
      path: Apps/iOS/HabitMap/HabitMap.entitlements
      properties:
        com.apple.developer.icloud-container-identifiers:
          - iCloud.com.adam.habitmap
        com.apple.developer.icloud-services:
          - CloudKit
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.access: []
```

Also add background mode `processing` is already there; we need to add `BGTaskSchedulerPermittedIdentifiers` to the Info.plist properties:

```yaml
        BGTaskSchedulerPermittedIdentifiers:
          - com.adam.habitmap.health-refresh
```

- [ ] **Step 2: Write `HealthKitService.swift`**

```swift
import Foundation
import HealthKit

public final class HealthKitService: HealthKitProviding {
    private let store: HKHealthStore?

    public init() {
        self.store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    public var isAvailable: Bool { store != nil }

    public func authState(for metrics: Set<HealthMetric>) async -> HealthAuthState {
        guard let store else { return .unavailable }
        let types = metrics.compactMap(Self.objectType(for:))
        guard !types.isEmpty else { return .undetermined }
        // HKHealthStore.authorizationStatus(for:) is sync.
        let statuses = types.map { store.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .authorized }
        if statuses.contains(.sharingDenied) { return .denied(timesDenied: 1) }
        return .undetermined
    }

    @discardableResult
    public func requestAuthorization(for metrics: Set<HealthMetric>) async throws -> HealthAuthState {
        guard let store else { throw HealthKitError.unavailable }
        let types = Set(metrics.compactMap(Self.objectType(for:)))
        guard !types.isEmpty else { return .undetermined }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            return await authState(for: metrics)
        } catch {
            throw HealthKitError.authorizationFailed(underlying: error)
        }
    }

    public func todayTotal(for metric: HealthMetric, on date: Date) async throws -> Double {
        guard let store else { throw HealthKitError.unavailable }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.queryFailed(underlying: nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        if let qt = Self.quantityType(for: metric) {
            return try await sumQuantity(type: qt, unit: Self.unit(for: metric)!, predicate: predicate, on: store)
        }
        if metric == .workouts {
            return try await workoutCount(predicate: predicate, on: store)
        }
        if metric == .mindfulMinutes {
            return try await mindfulMinutes(predicate: predicate, on: store)
        }
        if metric == .sleep {
            return try await sleepMinutes(predicate: predicate, on: store)
        }
        throw HealthKitError.queryFailed(underlying: nil)
    }

    // MARK: - Static maps

    static func objectType(for metric: HealthMetric) -> HKObjectType? {
        switch metric {
        case .stepCount: return HKQuantityType(.stepCount)
        case .activeEnergy: return HKQuantityType(.activeEnergyBurned)
        case .standHours: return HKQuantityType(.appleStandTime)
        case .hydration: return HKQuantityType(.dietaryWater)
        case .distanceWalkingRunning: return HKQuantityType(.distanceWalkingRunning)
        case .heartRate: return HKQuantityType(.heartRate)
        case .workouts: return HKWorkoutType.workoutType()
        case .mindfulMinutes: return HKCategoryType(.mindfulSession)
        case .sleep: return HKCategoryType(.sleepAnalysis)
        }
    }

    static func quantityType(for metric: HealthMetric) -> HKQuantityType? {
        objectType(for: metric) as? HKQuantityType
    }

    static func unit(for metric: HealthMetric) -> HKUnit? {
        switch metric {
        case .stepCount: return .count()
        case .activeEnergy: return .kilocalorie()
        case .standHours: return .hour()
        case .hydration: return .literUnit(with: .milli)
        case .distanceWalkingRunning: return .meter()
        case .heartRate: return HKUnit.count().unitDivided(by: .minute())
        case .workouts, .mindfulMinutes, .sleep: return nil
        }
    }

    // MARK: - Query primitives

    private func sumQuantity(type: HKQuantityType,
                             unit: HKUnit,
                             predicate: NSPredicate,
                             on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(q)
        }
    }

    private func workoutCount(predicate: NSPredicate, on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKWorkoutType.workoutType(),
                                  predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                continuation.resume(returning: Double(samples?.count ?? 0))
            }
            store.execute(q)
        }
    }

    private func mindfulMinutes(predicate: NSPredicate, on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKCategoryType(.mindfulSession),
                                  predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                let total = (samples ?? []).reduce(0.0) { acc, sample in
                    acc + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                }
                continuation.resume(returning: total)
            }
            store.execute(q)
        }
    }

    private func sleepMinutes(predicate: NSPredicate, on store: HKHealthStore) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis),
                                  predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(underlying: error))
                    return
                }
                // Sum only inBed / asleep categories
                let total = (samples ?? []).compactMap { $0 as? HKCategorySample }
                    .filter { sample in
                        if let v = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                            return v == .inBed
                                || v == .asleepUnspecified
                                || v == .asleepCore
                                || v == .asleepDeep
                                || v == .asleepREM
                        }
                        return false
                    }
                    .reduce(0.0) { acc, sample in
                        acc + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    }
                continuation.resume(returning: total)
            }
            store.execute(q)
        }
    }
}
```

- [ ] **Step 3: Build, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
git add project.yml Apps/iOS/HabitMap/HabitMap.entitlements Apps/iOS/HabitMap/Info.plist Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "feat(health): add HealthKitService (production HKHealthStore wrapper)"
```

---

## Task 3: MockHealthKitProvider for tests

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/MockHealthKitProvider.swift`

This lives in the package's main sources (not `#if DEBUG`) so tests can use it without recompiling sources differently. Production code can also opt into it for SwiftUI previews on the simulator if needed.

- [ ] **Step 1: Write `MockHealthKitProvider.swift`**

```swift
import Foundation

/// In-memory fake for tests + previews. Records calls so tests can assert on them.
public final class MockHealthKitProvider: HealthKitProviding, @unchecked Sendable {
    public var isAvailable: Bool
    public var stubAuthState: HealthAuthState
    public var todayValues: [HealthMetric: Double]
    public var requestAuthCallCount: Int = 0
    public var lastRequestedMetrics: Set<HealthMetric> = []
    public var queriedMetrics: [HealthMetric] = []

    public init(isAvailable: Bool = true,
                stubAuthState: HealthAuthState = .authorized,
                todayValues: [HealthMetric: Double] = [:]) {
        self.isAvailable = isAvailable
        self.stubAuthState = stubAuthState
        self.todayValues = todayValues
    }

    public func authState(for metrics: Set<HealthMetric>) async -> HealthAuthState {
        if !isAvailable { return .unavailable }
        return stubAuthState
    }

    @discardableResult
    public func requestAuthorization(for metrics: Set<HealthMetric>) async throws -> HealthAuthState {
        requestAuthCallCount += 1
        lastRequestedMetrics = metrics
        if !isAvailable { throw HealthKitError.unavailable }
        return stubAuthState
    }

    public func todayTotal(for metric: HealthMetric, on date: Date) async throws -> Double {
        queriedMetrics.append(metric)
        if !isAvailable { throw HealthKitError.unavailable }
        return todayValues[metric] ?? 0
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Packages/HabitMapCore
git commit -m "feat(health): add MockHealthKitProvider for tests and previews"
```

---

## Task 4: HealthSyncService — orchestrator

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/HealthSyncService.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/HealthSyncServiceTests.swift`

- [ ] **Step 1: Write `HealthSyncService.swift`**

```swift
import Foundation
import SwiftData

@MainActor
public final class HealthSyncService: ObservableObject {
    public let provider: HealthKitProviding
    public let repository: HabitRepository
    @Published public private(set) var lastSyncedAt: Date?

    public init(provider: HealthKitProviding, repository: HabitRepository) {
        self.provider = provider
        self.repository = repository
    }

    /// Fetch every active `.autoHealth` habit, query its metric for today, upsert a completion.
    public func syncToday() async {
        let habits: [Habit]
        do {
            let pages = try repository.fetchPages(includeArchived: false)
            habits = pages.flatMap { ($0.habits ?? []).filter { !$0.isArchived && !$0.isPaused && $0.type == .autoHealth } }
        } catch {
            return
        }
        for habit in habits {
            await syncHabit(habit)
        }
        lastSyncedAt = Date()
    }

    public func syncHabit(_ habit: Habit) async {
        guard let metric = habit.healthMetric else { return }
        do {
            let value = try await provider.todayTotal(for: metric, on: Date())
            upsertCompletion(habit: habit, value: value)
        } catch {
            // Silent failure: existing completion (if any) is left intact.
        }
    }

    private func upsertCompletion(habit: Habit, value: Double) {
        let today = Date.startOfToday()
        let reps = Int(value)
        if let existing = habit.completion(on: today) {
            existing.reps = reps
            existing.loggedAt = Date()
            existing.sourceRaw = CompletionSource.health.rawValue
        } else {
            let completion = HabitCompletion(date: today, reps: reps, source: .health, habit: habit)
            repository.context.insert(completion)
        }
        try? repository.context.save()
    }
}
```

- [ ] **Step 2: Write `HealthSyncServiceTests.swift`**

```swift
import XCTest
import SwiftData
@testable import HabitMapCore

final class HealthSyncServiceTests: XCTestCase {
    var container: ModelContainer!
    var repo: HabitRepository!
    var provider: MockHealthKitProvider!
    var sync: HealthSyncService!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        repo = HabitRepository(context: container.mainContext)
        provider = MockHealthKitProvider(stubAuthState: .authorized,
                                         todayValues: [.stepCount: 7500])
        sync = HealthSyncService(provider: provider, repository: repo)
    }

    @MainActor
    func test_syncToday_createsCompletionForAutoHealthHabit() async throws {
        let page = try repo.createPage(name: "Health", emoji: "🩺", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D",
                                         type: .autoHealth, targetReps: 10000,
                                         weekdayMask: 0b01111111, on: page)
        habit.healthMetric = .stepCount
        habit.healthGoal = 10000
        try repo.context.save()

        await sync.syncToday()

        XCTAssertEqual(habit.completion(on: Date())?.reps, 7500)
        XCTAssertEqual(habit.completion(on: Date())?.source, .health)
    }

    @MainActor
    func test_syncToday_updatesExistingCompletion() async throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D",
                                         type: .autoHealth, targetReps: 10000,
                                         weekdayMask: 0b01111111, on: page)
        habit.healthMetric = .stepCount
        let completion = HabitCompletion(date: Date.startOfToday(), reps: 1000, habit: habit)
        repo.context.insert(completion)
        try repo.context.save()

        await sync.syncToday()

        XCTAssertEqual(habit.completion(on: Date())?.reps, 7500)
    }

    @MainActor
    func test_syncToday_skipsManualHabits() async throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        _ = try repo.createHabit(name: "WATER", emoji: "💧", accentHex: "#3DA4FF",
                                 type: .manualMultiple, targetReps: 4,
                                 weekdayMask: 0b01111111, on: page)

        await sync.syncToday()

        XCTAssertTrue(provider.queriedMetrics.isEmpty)
    }

    @MainActor
    func test_syncToday_setsLastSyncedAt() async throws {
        XCTAssertNil(sync.lastSyncedAt)
        await sync.syncToday()
        XCTAssertNotNil(sync.lastSyncedAt)
    }

    @MainActor
    func test_syncHabit_silentOnError() async throws {
        provider.isAvailable = false
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "STEPS", emoji: "👟", accentHex: "#FFB23D",
                                         type: .autoHealth, targetReps: 10000,
                                         weekdayMask: 0b01111111, on: page)
        habit.healthMetric = .stepCount
        try repo.context.save()

        await sync.syncHabit(habit)

        XCTAssertNil(habit.completion(on: Date()), "No completion should be created on error")
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/HealthSyncServiceTests
git add Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "feat(health): add HealthSyncService orchestrator with 5 tests"
```

---

## Task 5: MetricPickerView — grid of available metrics

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Habit/MetricPickerView.swift`

- [ ] **Step 1: Write `MetricPickerView.swift`**

```swift
import SwiftUI
import HabitMapCore

struct MetricOption: Identifiable, Hashable {
    let id: HealthMetric
    let label: String
    let emoji: String
    let defaultGoal: Double
    let unit: String
}

struct MetricPickerView: View {
    @Binding var metric: HealthMetric?
    @Binding var goal: Double
    let accent: Color

    static let options: [MetricOption] = [
        .init(id: .stepCount, label: "STEPS", emoji: "👟", defaultGoal: 10000, unit: "steps"),
        .init(id: .workouts, label: "WORKOUTS", emoji: "🏋️", defaultGoal: 1, unit: "sessions"),
        .init(id: .mindfulMinutes, label: "MINDFUL", emoji: "🧘", defaultGoal: 10, unit: "minutes"),
        .init(id: .sleep, label: "SLEEP", emoji: "💤", defaultGoal: 420, unit: "minutes"),
        .init(id: .standHours, label: "STAND", emoji: "🧍", defaultGoal: 12, unit: "hours"),
        .init(id: .activeEnergy, label: "CALORIES", emoji: "🔥", defaultGoal: 500, unit: "kcal"),
        .init(id: .hydration, label: "HYDRATION", emoji: "💧", defaultGoal: 2000, unit: "ml"),
        .init(id: .distanceWalkingRunning, label: "DISTANCE", emoji: "🏃", defaultGoal: 5000, unit: "meters")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(Self.options) { opt in
                    Button {
                        metric = opt.id
                        goal = opt.defaultGoal
                    } label: {
                        VStack(spacing: 6) {
                            Text(opt.emoji).font(.system(size: 24))
                            PixelText(opt.label, pixelSize: 2, color: metric == opt.id ? .black : accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(metric == opt.id ? accent : DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(metric == opt.id ? accent.darker(by: 0.2) : DesignTokens.Surface.tileBorder,
                                                   lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(opt.label)
                    .accessibilityAddTraits(metric == opt.id ? [.isButton, .isSelected] : .isButton)
                }
            }

            if let selected = metric, let opt = Self.options.first(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 10) {
                    PixelText("DAILY GOAL", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                    HStack(spacing: DesignTokens.Spacing.md) {
                        PixelButton("-", style: .secondary, accent: accent) {
                            goal = max(stepIncrement(for: opt), goal - stepIncrement(for: opt))
                        }.frame(width: 60)
                        VStack(spacing: 2) {
                            PixelText("\(Int(goal))", pixelSize: 5, color: accent)
                            Text(opt.unit)
                                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                                .tracking(1.0)
                                .foregroundColor(DesignTokens.Surface.mutedText)
                        }
                        .frame(maxWidth: .infinity)
                        PixelButton("+", style: .secondary, accent: accent) {
                            goal += stepIncrement(for: opt)
                        }.frame(width: 60)
                    }
                }
            }
        }
    }

    private func stepIncrement(for opt: MetricOption) -> Double {
        switch opt.id {
        case .stepCount: return 500
        case .workouts: return 1
        case .mindfulMinutes, .sleep, .standHours: return 5
        case .activeEnergy: return 50
        case .hydration: return 250
        case .distanceWalkingRunning: return 500
        case .heartRate: return 1
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Apps/iOS HabitMap.xcodeproj
git commit -m "feat(habit): add MetricPickerView for 8 HealthKit metrics"
```

---

## Task 6: Wizard Step 2 — add AUTO-FILL FROM HEALTH option

**Files:**
- Modify: `Apps/iOS/HabitMap/Screens/Habit/AddHabitWizardView.swift` — extend `WizardDraft` with metric + goal
- Modify: `Apps/iOS/HabitMap/Screens/Habit/AddHabitStep2View.swift` — add 4th type row + metric picker

- [ ] **Step 1: Extend `WizardDraft` in `AddHabitWizardView.swift`**

Add to the struct:
```swift
var healthMetric: HealthMetric? = nil
var healthGoal: Double = 10000
```

And in `create()`, when `draft.type == .autoHealth`:
```swift
let reps: Int
switch draft.type {
case .manualOnce: reps = 1
case .inverse: reps = 0
case .manualMultiple: reps = draft.targetReps
case .autoHealth: reps = Int(draft.healthGoal)
}
let habit = try? repo.createHabit(...)
if draft.type == .autoHealth {
    habit?.healthMetric = draft.healthMetric
    habit?.healthGoal = draft.healthGoal
    try? repo.context.save()
}
```

- [ ] **Step 2: Modify `AddHabitStep2View.swift` — add 4th type row + conditional MetricPicker**

```swift
// Inside the type rows VStack, add:
if HKHealthStore_isAvailable() {
    typeRow(.autoHealth, label: "AUTO-FILL FROM HEALTH", subtitle: "Apple Health populates progress")
}

// At the bottom, replace the `if draft.type == .manualMultiple` block:
if draft.type == .manualMultiple {
    // ... existing stepper UI ...
} else if draft.type == .autoHealth {
    MetricPickerView(metric: $draft.healthMetric, goal: $draft.healthGoal, accent: Color(hex: draft.accentHex))
}
```

Where `HKHealthStore_isAvailable()` is a free function:
```swift
import HealthKit
private func HKHealthStore_isAvailable() -> Bool {
    HKHealthStore.isHealthDataAvailable()
}
```

Also update `canAdvance` for step 1 → require `draft.healthMetric != nil` if `.autoHealth`.

- [ ] **Step 3: Build, manual smoke, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
git add Apps/iOS HabitMap.xcodeproj
git commit -m "feat(wizard): add AUTO-FILL FROM HEALTH option with metric picker"
```

---

## Task 7: HabitRow — auth-aware UI for .autoHealth habits

**Files:**
- Modify: `Apps/iOS/HabitMap/Screens/Today/HabitRow.swift`

- [ ] **Step 1: Add health auth state to `HabitRow`**

Inject `HealthSyncService` via `@EnvironmentObject`. Read `provider.authState(for:)` async on appear and cache it as state. Subtitle / cell change based on state:

```swift
@EnvironmentObject private var sync: HealthSyncService
@State private var healthAuth: HealthAuthState = .undetermined

// In body, on appear:
.task {
    if habit.type == .autoHealth, let metric = habit.healthMetric {
        healthAuth = await sync.provider.authState(for: [metric])
    }
}

// In subtitle computed property:
private var subtitle: String {
    if habit.type == .autoHealth {
        switch healthAuth {
        case .unavailable: return "HEALTH UNAVAILABLE"
        case .undetermined: return "TAP TO AUTHORIZE"
        case .denied(let n) where n < 2: return "TAP TO AUTHORIZE"
        case .denied: return "SWITCH TO MANUAL?"
        case .authorized:
            let reps = habit.completion(on: Date())?.reps ?? 0
            let goal = Int(habit.healthGoal ?? Double(habit.targetReps))
            return "\(reps) / \(goal)"
        }
    }
    // existing switch for other types ...
}

// Tap handler change for autoHealth:
case .autoHealth:
    switch healthAuth {
    case .undetermined, .denied(let n) where n < 2:
        Task {
            guard let metric = habit.healthMetric else { return }
            do {
                let newState = try await sync.provider.requestAuthorization(for: [metric])
                healthAuth = newState
                if case .authorized = newState {
                    await sync.syncHabit(habit)
                }
            } catch {
                healthAuth = .denied(timesDenied: 1)
            }
        }
    case .denied:
        // 2nd denial: convert to manual
        habit.type = .manualOnce
        try? sync.repository.context.save()
    default:
        break
    }
```

- [ ] **Step 2: Build, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
git add Apps/iOS HabitMap.xcodeproj
git commit -m "feat(habit): HabitRow shows auth state + tap-to-authorize for autoHealth"
```

---

## Task 8: Wire HealthSyncService into the app + scene modifiers

**Files:**
- Modify: `Apps/iOS/HabitMap/HabitMapApp.swift`

- [ ] **Step 1: Update `HabitMapApp.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore
import BackgroundTasks

@main
struct HabitMapApp: App {
    let container: ModelContainer
    @StateObject private var repo: HabitRepository
    @StateObject private var sync: HealthSyncService

    private let healthRefreshIdentifier = "com.adam.habitmap.health-refresh"

    init() {
        do {
            let container = try PersistenceController.makeContainer(enableCloudKit: false)
            self.container = container
            let repo = HabitRepository(context: container.mainContext)
            let provider: HealthKitProviding = HealthKitService()
            _repo = StateObject(wrappedValue: repo)
            _sync = StateObject(wrappedValue: HealthSyncService(provider: provider, repository: repo))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environmentObject(repo)
                .environmentObject(sync)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch { print("Seed failed: \(error)") }

                    await sync.syncToday()
                }
                .onChange(of: ScenePhase.active) { _, _ in
                    Task { await sync.syncToday() }
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(healthRefreshIdentifier)) {
            await sync.syncToday()
            await scheduleNextRefresh()
        }
    }

    private func scheduleNextRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: healthRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

Note: `onChange(of: ScenePhase.active)` requires `@Environment(\.scenePhase)`. Replace with:

```swift
@Environment(\.scenePhase) private var scenePhase

// In body, attach to the inner view:
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        Task { await sync.syncToday() }
    }
}
```

But `@Environment` doesn't work on `App` directly. Move the scene-phase logic to a small wrapper view inside `WindowGroup`:

```swift
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: HealthSyncService

    var body: some View {
        TodayView()
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await sync.syncToday() }
                }
            }
    }
}
```

Then `WindowGroup { RootView().environmentObject(repo).environmentObject(sync) }`.

- [ ] **Step 2: Build, commit**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
git add Apps/iOS HabitMap.xcodeproj
git commit -m "feat(app): wire HealthSyncService with scene-phase + background refresh"
```

---

## Task 9: HealthKit service smoke test (live provider)

**Files:**
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/HealthKitServiceTests.swift`

Since `HKHealthStore` can't be unit-tested against real data without provisioning, this test only validates the static type mappings and `isAvailable` flag — the parts that don't require permission.

- [ ] **Step 1: Write `HealthKitServiceTests.swift`**

```swift
import XCTest
import HealthKit
@testable import HabitMapCore

final class HealthKitServiceTests: XCTestCase {
    func test_objectTypeMappings_coverAllMetrics() {
        for metric in [HealthMetric.stepCount, .activeEnergy, .standHours, .hydration,
                       .distanceWalkingRunning, .heartRate, .workouts, .mindfulMinutes, .sleep] {
            XCTAssertNotNil(HealthKitService.objectType(for: metric),
                           "Missing HKObjectType mapping for \(metric)")
        }
    }

    func test_quantityTypeMapping_excludesNonQuantityMetrics() {
        XCTAssertNotNil(HealthKitService.quantityType(for: .stepCount))
        XCTAssertNil(HealthKitService.quantityType(for: .workouts))
        XCTAssertNil(HealthKitService.quantityType(for: .mindfulMinutes))
        XCTAssertNil(HealthKitService.quantityType(for: .sleep))
    }

    func test_unitMapping_returnsExpectedUnits() {
        XCTAssertEqual(HealthKitService.unit(for: .stepCount), .count())
        XCTAssertEqual(HealthKitService.unit(for: .activeEnergy), .kilocalorie())
        XCTAssertEqual(HealthKitService.unit(for: .distanceWalkingRunning), .meter())
        XCTAssertNil(HealthKitService.unit(for: .workouts))
        XCTAssertNil(HealthKitService.unit(for: .mindfulMinutes))
    }

    func test_isAvailable_matchesHKHealthStore() {
        let service = HealthKitService()
        XCTAssertEqual(service.isAvailable, HKHealthStore.isHealthDataAvailable())
    }
}
```

- [ ] **Step 2: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/HealthKitServiceTests
git add Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "test(health): add HealthKitService static-mapping tests"
```

---

## Task 10: UI test — create auto-health habit through wizard

**Files:**
- Create: `Apps/iOS/HabitMapUITests/AutoHealthWizardUITests.swift`

- [ ] **Step 1: Write `AutoHealthWizardUITests.swift`**

```swift
import XCTest

final class AutoHealthWizardUITests: XCTestCase {
    /// Verifies the wizard can reach Step 2's AUTO-FILL FROM HEALTH option
    /// and pick a metric. We don't tap CREATE because that would trigger the
    /// HealthKit permission sheet which is system-modal and not easily dismissed
    /// in CI.
    func test_wizard_reachesAutoHealthOptionAndPicksSteps() throws {
        let app = XCUIApplication()
        app.launch()

        let fab = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add habit'")).firstMatch
        XCTAssertTrue(fab.waitForExistence(timeout: 10))
        fab.tap()

        XCTAssertTrue(app.navigationBars["NEW HABIT"].waitForExistence(timeout: 5))

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("WALK")

        app.buttons["NEXT"].firstMatch.tap()

        let autoRow = app.buttons["AUTO-FILL FROM HEALTH"].firstMatch
        XCTAssertTrue(autoRow.waitForExistence(timeout: 5),
                      "Expected AUTO-FILL FROM HEALTH option in Step 2")
        autoRow.tap()

        let stepsMetric = app.buttons["STEPS"].firstMatch
        XCTAssertTrue(stepsMetric.waitForExistence(timeout: 5),
                      "Expected STEPS metric in MetricPickerView")
        stepsMetric.tap()
    }
}
```

- [ ] **Step 2: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapUITests/AutoHealthWizardUITests
git add Apps/iOS HabitMap.xcodeproj
git commit -m "test(ui): verify wizard reaches AUTO-FILL FROM HEALTH and picks a metric"
```

---

## Task 11: Final verification + Plan 03 handoff

- [ ] **Step 1: Full test sweep**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

- [ ] **Step 2: Manual smoke**

1. Launch app on iPhone 16 simulator. The seeded HEALTH page + DRINK WATER habit appear (manual).
2. Tap FAB → wizard. Name "STEPS", emoji 👟, accent orange, NEXT.
3. Step 2: select AUTO-FILL FROM HEALTH, then STEPS metric. Goal 10000.
4. NEXT → Step 3 → CREATE.
5. New STEPS habit appears on Today. Subtitle says "TAP TO AUTHORIZE".
6. Tap the today cell → iOS permission sheet appears (in simulator) → tap Turn On All → permission granted.
7. Subtitle changes to "0 / 10000" (simulator has no health data by default). Behavior is correct; on a real device with steps logged, the value would populate.

- [ ] **Step 3: Write `docs/plan-03-handoff.md`**

Document deviations and open questions for Plan 04 (Heat Map screen).

- [ ] **Step 4: Final commit**

```bash
git add docs/
git commit -m "docs: plan 03 complete, handoff to plan 04 (Heat Map)"
```

---

## Verification

End-to-end manual test on iPhone 16 simulator:
1. Wizard → AUTO-FILL FROM HEALTH option visible.
2. Pick STEPS metric, goal 10000, schedule, create.
3. Habit appears on Today with "TAP TO AUTHORIZE" state.
4. Tap → permission sheet appears.
5. Authorize → habit shows current progress (0 on simulator without data; real value on device).
6. Cold relaunch → sync runs on launch, progress refreshes.
7. Re-deny permission scenario → after 2nd denial, habit converts to manual.

Automated: `xcodebuild test ...` — all unit + snapshot + UI tests pass.

## Out of scope for this plan
Heat Map screen · Day-detail journal · Insights · Risk Forecast · Notification scheduling · Settings · Reset Data · Widgets · Live Activity · Apple Watch · iPad layouts · Onboarding · Themes · CloudKit cutover · live device testing.
