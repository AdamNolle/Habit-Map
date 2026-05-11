# Habit Map — Plan 06: Notifications + Settings + Reset Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tap SETUP in the tab bar to open `SettingsView`. Users can toggle forgiveness behavior, configure notification tone (gentle/direct) + daily reminder time + weekly reflection, manage pages, view about info, and trigger a 3-step Reset Data flow. A `NotificationScheduler` schedules daily-reminder + weekly-reflection notifications via `UNUserNotificationCenter`. Copy is enforced safe — gentle-tone strings can never contain banned phrases like `broken`, `failed`, `missed`.

**Architecture:** `NotificationScheduling` protocol abstracts `UNUserNotificationCenter` so the scheduler is testable with a fake. `NotificationScheduler` orchestrates: request permission → cancel-all → schedule daily reminder + weekly reflection based on `UserSettings`. `NotificationCopy` produces tone-aware strings with a `DEBUG`-only `assertSafe(_:)` guard. `SettingsView` is a pixel-art-styled `ScrollView`. Reset Data is a 3-step `Alert` chain that ends in `HabitRepository.deleteAll(scope:)`.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 17+, UserNotifications, SwiftData. No new third-party deps.

---

## Context

Plans 01-05 shipped: foundation, pages/habits CRUD, HealthKit, heat map, insights. SETUP tab currently shows `ComingSoonView`. `UserSettings` model exists (Plan 01) but isn't wired to any UI. `Habit.reminderTime` is stored but no notification fires.

**Defining scope for this plan:**
- ✅ Daily reminder + weekly reflection (Sunday 8pm) scheduling
- ✅ Notification permission request (lazy, when user enables in Settings)
- ✅ Gentle / direct tone presets with banned-phrases guard
- ✅ Full `SettingsView` with all 6 spec sections
- ✅ 3-step Reset Data flow with in-DB wipe (no iCloud snapshot until CloudKit lands)
- ❌ Per-habit reminders (the `Habit.reminderTime` field stays unused for now; a follow-up plan will batch-schedule per-habit notifications)
- ❌ Risk alerts (need 6h-ahead prediction scheduling; deferred to a polish plan)
- ❌ CSV export from Settings (placeholder row only — file-format work is its own plan)

**Confirmed decisions from Plan 05 handoff:**
- `NotificationScheduler` is a `@MainActor ObservableObject` injected as `EnvironmentObject`
- Pixel-art-styled Settings (not `Form`)
- Banned-phrases enforced via DEBUG `assertSafe` + test sweep
- Reset Data in-DB only

---

## File Structure (new additions)

```
Packages/HabitMapCore/
  Sources/HabitMapCore/
    Services/
      NotificationCopy.swift              # tone-aware copy + assertSafe guard
      NotificationScheduling.swift        # protocol
      NotificationScheduler.swift         # UNUserNotificationCenter impl
      MockNotificationScheduler.swift     # tests + previews
    Models/
      UserSettings+Singleton.swift        # fetchOrCreate helper
    Services/
      HabitRepository.swift               # (modified) deleteAll(scope:) + UserSettings helper
  Tests/HabitMapCoreTests/
    NotificationCopyTests.swift           # banned-phrases sweep + tone variants
    NotificationSchedulerTests.swift      # schedule/cancel behavior via mock
    UserSettingsSingletonTests.swift

Apps/iOS/HabitMap/
  Screens/
    Settings/
      SettingsView.swift                  # all 6 sections
      ResetDataAlertChain.swift           # 3-step alert state machine
      AboutSection.swift                  # version row
  HabitMapApp.swift                       # (modified) inject scheduler, route SETUP
HabitMapUITests/
  SettingsNavigationUITests.swift
```

---

## Task 1: NotificationCopy + banned-phrases guard

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/NotificationCopy.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/NotificationCopyTests.swift`

- [ ] **Step 1: Write `NotificationCopy.swift`**

```swift
import Foundation

public enum NotificationCopy {
    /// Phrases that should NEVER appear in gentle-tone notification body text.
    /// Matched case-insensitively.
    public static let bannedInGentle: [String] = [
        "broken", "failed", "missed", "you didn't", "streak lost", "DON'T", "don't"
    ]

    // MARK: - Daily reminder

    public static func dailyReminderTitle(tone: NotificationTone) -> String {
        switch tone {
        case .gentle: return "Habit Map"
        case .direct: return "REMINDERS"
        }
    }

    public static func dailyReminderBody(tone: NotificationTone, pendingCount: Int) -> String {
        let body: String
        switch tone {
        case .gentle:
            if pendingCount == 0 {
                body = "Today is open — log when you're ready."
            } else {
                body = "\(pendingCount) habit\(pendingCount == 1 ? "" : "s") waiting whenever you're ready."
            }
        case .direct:
            body = "\(pendingCount) habit\(pendingCount == 1 ? "" : "s") remaining today."
        }
        assertSafe(body, tone: tone)
        return body
    }

    // MARK: - Weekly reflection

    public static func weeklyReflectionTitle(tone: NotificationTone) -> String {
        switch tone {
        case .gentle: return "Weekly Reflection"
        case .direct: return "WEEKLY REVIEW"
        }
    }

    public static func weeklyReflectionBody(tone: NotificationTone) -> String {
        let body: String
        switch tone {
        case .gentle:
            body = "Take a moment to look back. What worked this week?"
        case .direct:
            body = "Week summary ready. Review now."
        }
        assertSafe(body, tone: tone)
        return body
    }

    // MARK: - Safety

    /// In DEBUG, crashes if gentle-tone copy contains a banned phrase. In release, logs.
    public static func assertSafe(_ body: String, tone: NotificationTone) {
        guard tone == .gentle else { return }
        let lower = body.lowercased()
        for phrase in bannedInGentle {
            if lower.contains(phrase.lowercased()) {
                #if DEBUG
                assertionFailure("Banned phrase '\(phrase)' in gentle copy: \(body)")
                #else
                print("WARN: banned phrase '\(phrase)' in gentle copy: \(body)")
                #endif
                return
            }
        }
    }
}
```

- [ ] **Step 2: Write `NotificationCopyTests.swift`**

```swift
import XCTest
@testable import HabitMapCore

final class NotificationCopyTests: XCTestCase {
    func test_dailyReminder_gentleHasNoBannedPhrase() {
        for n in [0, 1, 3, 10] {
            let body = NotificationCopy.dailyReminderBody(tone: .gentle, pendingCount: n)
            assertNoBannedPhrase(body)
        }
    }

    func test_dailyReminder_directIsTerse() {
        let body = NotificationCopy.dailyReminderBody(tone: .direct, pendingCount: 3)
        XCTAssertTrue(body.contains("3 habits"))
    }

    func test_dailyReminder_pluralizationOne() {
        let body = NotificationCopy.dailyReminderBody(tone: .direct, pendingCount: 1)
        XCTAssertTrue(body.contains("1 habit "))
    }

    func test_dailyReminder_pendingZero_gentleSaysOpen() {
        let body = NotificationCopy.dailyReminderBody(tone: .gentle, pendingCount: 0)
        XCTAssertTrue(body.contains("open"))
    }

    func test_weeklyReflection_gentleHasNoBannedPhrase() {
        let body = NotificationCopy.weeklyReflectionBody(tone: .gentle)
        assertNoBannedPhrase(body)
    }

    func test_titles_returnExpectedStrings() {
        XCTAssertEqual(NotificationCopy.dailyReminderTitle(tone: .gentle), "Habit Map")
        XCTAssertEqual(NotificationCopy.dailyReminderTitle(tone: .direct), "REMINDERS")
        XCTAssertEqual(NotificationCopy.weeklyReflectionTitle(tone: .gentle), "Weekly Reflection")
        XCTAssertEqual(NotificationCopy.weeklyReflectionTitle(tone: .direct), "WEEKLY REVIEW")
    }

    private func assertNoBannedPhrase(_ body: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let lower = body.lowercased()
        for phrase in NotificationCopy.bannedInGentle {
            XCTAssertFalse(lower.contains(phrase.lowercased()),
                           "Gentle copy contains banned phrase '\(phrase)': \(body)",
                           file: file, line: line)
        }
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
xcodegen generate
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/NotificationCopyTests
git add Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "feat(notifications): add NotificationCopy with tone presets + banned-phrases guard"
```

---

## Task 2: NotificationScheduling protocol + scheduler

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/NotificationScheduling.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/NotificationScheduler.swift`
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/MockNotificationScheduler.swift`

- [ ] **Step 1: Write `NotificationScheduling.swift`**

```swift
import Foundation

public struct ScheduledNotification: Sendable, Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let weekday: Int?      // 1=Sunday ... 7=Saturday (Calendar convention), nil = daily
    public let hour: Int
    public let minute: Int

    public init(identifier: String, title: String, body: String,
                weekday: Int? = nil, hour: Int, minute: Int) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }
}

public enum NotificationAuthState: Sendable, Equatable {
    case undetermined, authorized, denied
}

public protocol NotificationScheduling: Sendable {
    func authState() async -> NotificationAuthState
    @discardableResult
    func requestAuthorization() async throws -> NotificationAuthState
    func schedule(_ notification: ScheduledNotification) async throws
    func cancel(identifier: String) async
    func cancelAll() async
    func pendingIdentifiers() async -> [String]
}
```

- [ ] **Step 2: Write `NotificationScheduler.swift`**

```swift
import Foundation
import UserNotifications

public final class NotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authState() async -> NotificationAuthState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .undetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .undetermined
        }
    }

    @discardableResult
    public func requestAuthorization() async throws -> NotificationAuthState {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ? .authorized : .denied
    }

    public func schedule(_ notification: ScheduledNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        var components = DateComponents()
        components.hour = notification.hour
        components.minute = notification.minute
        if let weekday = notification.weekday {
            components.weekday = weekday
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notification.identifier,
                                            content: content,
                                            trigger: trigger)
        try await center.add(request)
    }

    public func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    public func pendingIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(\.identifier)
    }
}
```

- [ ] **Step 3: Write `MockNotificationScheduler.swift`**

```swift
import Foundation

public final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    public var stubAuthState: NotificationAuthState
    public var scheduled: [ScheduledNotification] = []
    public var authRequestCount: Int = 0

    public init(stubAuthState: NotificationAuthState = .authorized) {
        self.stubAuthState = stubAuthState
    }

    public func authState() async -> NotificationAuthState { stubAuthState }

    @discardableResult
    public func requestAuthorization() async throws -> NotificationAuthState {
        authRequestCount += 1
        return stubAuthState
    }

    public func schedule(_ notification: ScheduledNotification) async throws {
        scheduled.removeAll { $0.identifier == notification.identifier }
        scheduled.append(notification)
    }

    public func cancel(identifier: String) async {
        scheduled.removeAll { $0.identifier == identifier }
    }

    public func cancelAll() async {
        scheduled.removeAll()
    }

    public func pendingIdentifiers() async -> [String] {
        scheduled.map(\.identifier)
    }
}
```

- [ ] **Step 4: Write `NotificationSchedulerTests.swift`**

```swift
import XCTest
@testable import HabitMapCore

final class NotificationSchedulerTests: XCTestCase {
    func test_schedule_addsToScheduled() async throws {
        let mock = MockNotificationScheduler()
        let n = ScheduledNotification(identifier: "x", title: "t", body: "b", hour: 7, minute: 0)
        try await mock.schedule(n)
        let ids = await mock.pendingIdentifiers()
        XCTAssertEqual(ids, ["x"])
    }

    func test_schedule_dedupesByIdentifier() async throws {
        let mock = MockNotificationScheduler()
        let n1 = ScheduledNotification(identifier: "x", title: "t1", body: "b", hour: 7, minute: 0)
        let n2 = ScheduledNotification(identifier: "x", title: "t2", body: "b", hour: 8, minute: 0)
        try await mock.schedule(n1); try await mock.schedule(n2)
        XCTAssertEqual(mock.scheduled.count, 1)
        XCTAssertEqual(mock.scheduled.first?.title, "t2")
    }

    func test_cancel_removesIdentifier() async throws {
        let mock = MockNotificationScheduler()
        try await mock.schedule(ScheduledNotification(identifier: "a", title: "t", body: "b", hour: 7, minute: 0))
        try await mock.schedule(ScheduledNotification(identifier: "b", title: "t", body: "b", hour: 7, minute: 0))
        await mock.cancel(identifier: "a")
        let ids = await mock.pendingIdentifiers()
        XCTAssertEqual(ids, ["b"])
    }

    func test_cancelAll_clears() async throws {
        let mock = MockNotificationScheduler()
        try await mock.schedule(ScheduledNotification(identifier: "a", title: "t", body: "b", hour: 7, minute: 0))
        await mock.cancelAll()
        let ids = await mock.pendingIdentifiers()
        XCTAssertTrue(ids.isEmpty)
    }

    func test_requestAuthorization_incrementsCounter() async throws {
        let mock = MockNotificationScheduler(stubAuthState: .authorized)
        _ = try await mock.requestAuthorization()
        XCTAssertEqual(mock.authRequestCount, 1)
    }
}
```

- [ ] **Step 5: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/NotificationSchedulerTests
git commit -m "feat(notifications): add NotificationScheduling protocol + UN-backed impl + mock"
```

---

## Task 3: UserSettings singleton helper + repository deleteAll

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Models/UserSettings+Singleton.swift`
- Modify: `Packages/HabitMapCore/Sources/HabitMapCore/Services/HabitRepository.swift` — add `userSettings()` getter + `deleteAll(scope:)`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/UserSettingsSingletonTests.swift`

- [ ] **Step 1: Write `UserSettings+Singleton.swift`**

```swift
import Foundation
import SwiftData

public extension UserSettings {
    /// Fetch the single UserSettings record, creating one with defaults if it doesn't exist.
    @MainActor
    static func fetchOrCreate(in context: ModelContext) throws -> UserSettings {
        let existing = try context.fetch(FetchDescriptor<UserSettings>())
        if let first = existing.first { return first }
        let new = UserSettings()
        context.insert(new)
        try context.save()
        return new
    }
}
```

- [ ] **Step 2: Modify `HabitRepository.swift` — add `userSettings()` + `deleteAll(scope:)`**

Append at the bottom of the class:

```swift
    // MARK: - Settings

    public func userSettings() throws -> UserSettings {
        try UserSettings.fetchOrCreate(in: context)
    }

    // MARK: - Reset

    public enum DeleteScope: Sendable {
        case currentPage(HabitPage)
        case archivedOnly
        case everything
    }

    public func deleteAll(scope: DeleteScope) throws {
        switch scope {
        case .currentPage(let page):
            for habit in (page.habits ?? []) {
                context.delete(habit)
            }
            context.delete(page)
        case .archivedOnly:
            for page in try fetchPages(includeArchived: true) where page.isArchived {
                for habit in (page.habits ?? []) {
                    context.delete(habit)
                }
                context.delete(page)
            }
        case .everything:
            // Wipe everything: pages, habits, completions, settings.
            let pages = try fetchPages(includeArchived: true)
            for page in pages {
                for habit in (page.habits ?? []) {
                    context.delete(habit)
                }
                context.delete(page)
            }
            // Also wipe orphan completions, just in case.
            let allCompletions = try context.fetch(FetchDescriptor<HabitCompletion>())
            for c in allCompletions { context.delete(c) }
            // Reset settings to defaults by deleting and recreating.
            let allSettings = try context.fetch(FetchDescriptor<UserSettings>())
            for s in allSettings { context.delete(s) }
        }
        try context.save()
    }
```

- [ ] **Step 3: Write `UserSettingsSingletonTests.swift`**

```swift
import XCTest
import SwiftData
@testable import HabitMapCore

final class UserSettingsSingletonTests: XCTestCase {
    var container: ModelContainer!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
    }

    @MainActor
    func test_fetchOrCreate_returnsExisting() throws {
        let ctx = container.mainContext
        let original = try UserSettings.fetchOrCreate(in: ctx)
        original.themeAccentHex = "#FF0000"
        try ctx.save()

        let again = try UserSettings.fetchOrCreate(in: ctx)
        XCTAssertEqual(again.id, original.id)
        XCTAssertEqual(again.themeAccentHex, "#FF0000")
    }

    @MainActor
    func test_fetchOrCreate_createsWhenMissing() throws {
        let ctx = container.mainContext
        let settings = try UserSettings.fetchOrCreate(in: ctx)
        XCTAssertEqual(settings.showRecoveryRate, true)
        XCTAssertEqual(settings.notificationTone, .gentle)
    }

    @MainActor
    func test_deleteAll_everything_clearsStore() throws {
        let ctx = container.mainContext
        let repo = HabitRepository(context: ctx)
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        _ = try repo.createHabit(name: "H", emoji: "💧", accentHex: "#3DA4FF",
                                 type: .manualOnce, targetReps: 1,
                                 weekdayMask: 0b01111111, on: page)
        _ = try repo.userSettings()

        try repo.deleteAll(scope: .everything)

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<HabitPage>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Habit>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<UserSettings>()), 0)
    }

    @MainActor
    func test_deleteAll_archivedOnly_keepsActive() throws {
        let ctx = container.mainContext
        let repo = HabitRepository(context: ctx)
        let active = try repo.createPage(name: "A", emoji: "🅰", accentHex: "#2BFF5F")
        let archived = try repo.createPage(name: "B", emoji: "🅱", accentHex: "#3DA4FF")
        try repo.archivePage(archived)

        try repo.deleteAll(scope: .archivedOnly)

        let remaining = try repo.fetchPages(includeArchived: true)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, active.id)
    }
}
```

- [ ] **Step 4: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/UserSettingsSingletonTests
git commit -m "feat(settings): add UserSettings.fetchOrCreate + HabitRepository.deleteAll(scope:)"
```

---

## Task 4: SettingsView with all 6 sections

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Settings/SettingsView.swift`
- Create: `Apps/iOS/HabitMap/Screens/Settings/AboutSection.swift`

- [ ] **Step 1: Write `AboutSection.swift`**

```swift
import SwiftUI
import HabitMapCore

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ABOUT")
            row(label: "VERSION", value: HabitMapCore.version)
            row(label: "BUILD", value: buildNumber)
            navRow(label: "PRIVACY POLICY") {
                if let url = URL(string: "https://habitmap.app/privacy") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            PixelText(label, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.heavy))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }

    private func navRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                PixelText(label, pixelSize: 2, color: DesignTokens.Accent.classicGreen)
                Spacer()
                PixelText(">", pixelSize: 2, color: DesignTokens.Accent.classicGreen)
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ text: String) -> some View {
        PixelText(text, pixelSize: 3, color: DesignTokens.Accent.classicGreen)
            .padding(.top, 8)
    }
}
```

- [ ] **Step 2: Write `SettingsView.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

struct SettingsView: View {
    @EnvironmentObject private var repo: HabitRepository
    @EnvironmentObject private var notifications: NotificationCoordinator
    @State private var showPages = false
    @State private var resetState: ResetStep = .idle
    @State private var resetScope: ResetScope = .everything
    @State private var resetConfirmation: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                PixelText("SETTINGS", pixelSize: 4, color: DesignTokens.Accent.classicGreen)
                    .accessibilityLabel("SETTINGS")
                    .accessibilityAddTraits(.isHeader)

                forgivenessSection
                notificationsSection
                pagesSection
                dataSyncSection
                dangerZoneSection
                AboutSection()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Surface.bg)
        .sheet(isPresented: $showPages) {
            PagesManagerView().environmentObject(repo)
        }
        .preferredColorScheme(.dark)
        .alert("Reset what?", isPresented: Binding(get: { resetState == .scope }, set: { if !$0 { resetState = .idle } })) {
            Button("Everything") { resetScope = .everything; resetState = .confirm }
            Button("Archived pages only") { resetScope = .archived; resetState = .confirm }
            Button("Cancel", role: .cancel) { resetState = .idle }
        }
        .alert("Type RESET to confirm", isPresented: Binding(get: { resetState == .confirm }, set: { if !$0 { resetState = .idle } })) {
            TextField("RESET", text: $resetConfirmation)
                .textInputAutocapitalization(.characters)
            Button("Confirm", role: .destructive) {
                if resetConfirmation.uppercased() == "RESET" {
                    performReset()
                }
                resetState = .idle
                resetConfirmation = ""
            }
            Button("Cancel", role: .cancel) {
                resetState = .idle
                resetConfirmation = ""
            }
        } message: {
            Text(resetScope == .everything
                 ? "This will permanently delete every page, habit, and completion. There is no undo."
                 : "This will permanently delete all archived pages.")
        }
    }

    // MARK: - Sections

    private var forgivenessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("FORGIVENESS")
            ToggleRow(label: "SHOW RECOVERY RATE",
                      isOn: Binding(get: { settings.showRecoveryRate },
                                    set: { settings.showRecoveryRate = $0; save() }))
            ToggleRow(label: "REST DAYS DON'T COUNT",
                      isOn: Binding(get: { settings.restDaysDontCount },
                                    set: { settings.restDaysDontCount = $0; save() }))
            StepperRow(label: "CALM MODE THRESHOLD",
                       value: Binding(get: { settings.calmModeThreshold },
                                      set: { settings.calmModeThreshold = $0; save() }),
                       displayed: "\(Int(settings.calmModeThreshold * 100))%",
                       step: 0.05, range: 0.10...0.80)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("NOTIFICATIONS")
            HStack {
                PixelText("TONE", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                Spacer()
                Picker("", selection: Binding(get: { settings.notificationTone },
                                              set: { settings.notificationTone = $0; save(); reschedule() })) {
                    Text("Gentle").tag(NotificationTone.gentle)
                    Text("Direct").tag(NotificationTone.direct)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))

            ToggleRow(label: "DAILY REMINDER",
                      isOn: Binding(get: { settings.dailyReminderTime != nil },
                                    set: { on in
                                        if on {
                                            settings.dailyReminderTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
                                        } else {
                                            settings.dailyReminderTime = nil
                                        }
                                        save(); reschedule()
                                    }))
            if let time = settings.dailyReminderTime {
                DatePicker("", selection: Binding(get: { time },
                                                  set: { settings.dailyReminderTime = $0; save(); reschedule() }),
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 12)
            }
            ToggleRow(label: "WEEKLY REFLECTION",
                      isOn: Binding(get: { settings.weeklyReflectionEnabled },
                                    set: { settings.weeklyReflectionEnabled = $0; save(); reschedule() }))
        }
    }

    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("PAGES")
            Button { showPages = true } label: {
                HStack {
                    PixelText("MANAGE PAGES", pixelSize: 2, color: DesignTokens.Accent.classicGreen)
                    Spacer()
                    PixelText(">", pixelSize: 2, color: DesignTokens.Accent.classicGreen)
                }
                .padding(12)
                .background(DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSyncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DATA · SYNC")
            ToggleRow(label: "ICLOUD SYNC",
                      isOn: Binding(get: { settings.iCloudSyncEnabled },
                                    set: { settings.iCloudSyncEnabled = $0; save() }))
            disabledRow(label: "EXPORT CSV (SOON)")
            disabledRow(label: "IMPORT / RESTORE (SOON)")
        }
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DANGER ZONE")
            Button {
                resetConfirmation = ""
                resetState = .scope
            } label: {
                HStack {
                    PixelText("RESET ALL DATA", pixelSize: 2, color: DesignTokens.Surface.miss)
                    Spacer()
                    PixelText(">", pixelSize: 2, color: DesignTokens.Surface.miss)
                }
                .padding(12)
                .background(DesignTokens.Surface.card)
                .overlay(Rectangle().stroke(DesignTokens.Surface.miss, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset all data")
        }
    }

    // MARK: - Helpers

    private var settings: UserSettings {
        (try? repo.userSettings()) ?? UserSettings()
    }

    private func save() {
        try? repo.context.save()
    }

    private func reschedule() {
        Task { await notifications.reschedule() }
    }

    private func performReset() {
        try? repo.deleteAll(scope: resetScope == .everything ? .everything : .archivedOnly)
    }

    private enum ResetStep { case idle, scope, confirm }
    private enum ResetScope { case everything, archived }

    private func sectionHeader(_ text: String) -> some View {
        PixelText(text, pixelSize: 3, color: DesignTokens.Accent.classicGreen)
            .padding(.top, 8)
    }

    private func disabledRow(label: String) -> some View {
        HStack {
            PixelText(label, pixelSize: 2, color: DesignTokens.Surface.dimText)
            Spacer()
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }
}

// MARK: - Small reusable row views

struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            PixelText(label, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            Spacer()
            PixelToggle(isOn: $isOn)
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }
}

struct StepperRow: View {
    let label: String
    @Binding var value: Double
    let displayed: String
    let step: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            PixelText(label, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            Spacer()
            Stepper(displayed, value: $value, in: range, step: step)
                .labelsHidden()
            Text(displayed)
                .font(.system(.body, design: .monospaced).weight(.heavy))
                .foregroundColor(DesignTokens.Accent.classicGreen)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Surface.cardBorder, lineWidth: 1))
    }
}
```

- [ ] **Step 3: Commit (build + run after Task 5 below — they cross-reference `NotificationCoordinator`)**

```bash
# Don't commit yet; awaiting Task 5
```

---

## Task 5: NotificationCoordinator + wire app

**Files:**
- Modify: `Apps/iOS/HabitMap/HabitMapApp.swift`

`NotificationCoordinator` is a thin `@MainActor ObservableObject` that owns a `NotificationScheduling` instance and exposes `reschedule()` which: (a) cancels all, (b) re-reads `UserSettings`, (c) schedules daily reminder + weekly reflection per settings. Live inside the app target since it bridges SwiftData + the scheduler.

- [ ] **Step 1: Modify `HabitMapApp.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore
import BackgroundTasks

@MainActor
final class NotificationCoordinator: ObservableObject {
    let scheduler: NotificationScheduling
    let repository: HabitRepository

    init(scheduler: NotificationScheduling, repository: HabitRepository) {
        self.scheduler = scheduler
        self.repository = repository
    }

    func reschedule() async {
        let auth = await scheduler.authState()
        guard auth == .authorized else { return }
        await scheduler.cancelAll()

        guard let settings = try? repository.userSettings() else { return }

        if let time = settings.dailyReminderTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            let pending = pendingCount()
            let body = NotificationCopy.dailyReminderBody(tone: settings.notificationTone, pendingCount: pending)
            let title = NotificationCopy.dailyReminderTitle(tone: settings.notificationTone)
            try? await scheduler.schedule(ScheduledNotification(
                identifier: "habitmap.daily-reminder",
                title: title, body: body,
                hour: comps.hour ?? 7, minute: comps.minute ?? 0
            ))
        }

        if settings.weeklyReflectionEnabled {
            let title = NotificationCopy.weeklyReflectionTitle(tone: settings.notificationTone)
            let body = NotificationCopy.weeklyReflectionBody(tone: settings.notificationTone)
            try? await scheduler.schedule(ScheduledNotification(
                identifier: "habitmap.weekly-reflection",
                title: title, body: body,
                weekday: 1,        // Sunday
                hour: 20, minute: 0
            ))
        }
    }

    func requestPermissionIfNeeded() async {
        let state = await scheduler.authState()
        if state == .undetermined {
            _ = try? await scheduler.requestAuthorization()
            await reschedule()
        }
    }

    private func pendingCount() -> Int {
        let pages = (try? repository.fetchPages()) ?? []
        return pages.flatMap { ($0.habits ?? []) }
            .filter { !$0.isArchived && !$0.isPaused && $0.isScheduled(Date()) }
            .filter { $0.progressFraction(on: Date()) < 1.0 }
            .count
    }
}

@main
struct HabitMapApp: App {
    let container: ModelContainer
    @StateObject private var repo: HabitRepository
    @StateObject private var sync: HealthSyncService
    @StateObject private var notifications: NotificationCoordinator

    private let healthRefreshIdentifier = "com.adam.habitmap.health-refresh"

    init() {
        do {
            let container = try PersistenceController.makeContainer(enableCloudKit: false)
            self.container = container
            let repo = HabitRepository(context: container.mainContext)
            let provider: HealthKitProviding = HealthKitService()
            let notifScheduler: NotificationScheduling = NotificationScheduler()
            _repo = StateObject(wrappedValue: repo)
            _sync = StateObject(wrappedValue: HealthSyncService(provider: provider, repository: repo))
            _notifications = StateObject(wrappedValue: NotificationCoordinator(scheduler: notifScheduler, repository: repo))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(repo)
                .environmentObject(sync)
                .environmentObject(notifications)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch { print("Seed failed: \(error)") }
                    await sync.syncToday()
                    await notifications.reschedule()
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

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: HealthSyncService
    @EnvironmentObject private var notifications: NotificationCoordinator
    @State private var activeTab: HabitMapTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .today: TodayView()
                case .map:   MapView()
                case .stats: InsightsView()
                case .setup: SettingsView()
                }
            }
            .padding(.bottom, 80)

            TabBar(active: activeTab) { tab in
                activeTab = tab
                if tab == .setup {
                    Task { await notifications.requestPermissionIfNeeded() }
                }
            }
        }
        .background(DesignTokens.Surface.bg)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await sync.syncToday() }
            }
        }
    }
}
```

- [ ] **Step 2: Add `aps-environment` entitlement to `project.yml`**

Append to the entitlements block:

```yaml
        aps-environment: development
```

- [ ] **Step 3: Build, manual smoke, commit Tasks 4 + 5 together**

```bash
xcodegen generate
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -quiet build
# Launch in simulator: tap SETUP → SettingsView appears.
# Toggle the notification options; permission sheet appears on first SETUP visit.
git add Apps/iOS Packages/HabitMapCore project.yml HabitMap.xcodeproj
git commit -m "feat(settings): SettingsView + NotificationCoordinator, route SETUP tab"
```

---

## Task 6: UI test — SETUP tab navigation

**Files:**
- Create: `Apps/iOS/HabitMapUITests/SettingsNavigationUITests.swift`

- [ ] **Step 1: Write the test**

```swift
import XCTest

final class SettingsNavigationUITests: XCTestCase {
    func test_tapSetupTab_revealsSettingsHeader() throws {
        let app = XCUIApplication()
        app.launch()

        let setupTab = app.buttons["SETUP tab"].firstMatch
        XCTAssertTrue(setupTab.waitForExistence(timeout: 10))
        setupTab.tap()

        // Dismiss the notification permission alert if it appears (we requested on tab change).
        // The system alert may take a moment; addUIInterruptionMonitor is the right way for
        // production tests, but for v1 we just check the header is present.
        let header = app.descendants(matching: .any).matching(identifier: "SETTINGS").firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 15)
                      || app.staticTexts["SETTINGS"].waitForExistence(timeout: 5),
                      "Expected SETTINGS header after tapping SETUP tab")
    }
}
```

- [ ] **Step 2: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapUITests/SettingsNavigationUITests
git commit -m "test(ui): verify SETUP tab reveals SETTINGS header"
```

---

## Task 7: Final verification + Plan 07 handoff + push

- [ ] **Step 1: Full test sweep**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

- [ ] **Step 2: Manual smoke**

1. Launch → seeded HEALTH page on Today.
2. Tap SETUP → permission sheet may appear; allow.
3. SettingsView renders with 6 sections: FORGIVENESS, NOTIFICATIONS, PAGES, DATA · SYNC, DANGER ZONE, ABOUT.
4. Toggle SHOW RECOVERY RATE off → persists across relaunch.
5. Toggle DAILY REMINDER on → time picker appears → set to 7:00 AM.
6. Toggle WEEKLY REFLECTION on.
7. Tap RESET ALL DATA → choose "Everything" → type RESET → confirm. App resets to empty state (seed re-runs and one HEALTH page reappears on Today).
8. Tap a fresh notification check: `xcrun simctl spawn booted notifyutil -d 1 || true` (informational).
9. Verify `pendingNotificationRequests()` shows two requests if you peek via Xcode debugger.

- [ ] **Step 3: Write `docs/plan-06-handoff.md`**

- [ ] **Step 4: Final commit + push**

```bash
git add docs/
git commit -m "docs: plan 06 complete, handoff to plan 07 (Widgets + Live Activity)"
git push
```

---

## Verification

End-to-end manual test on iPhone 16 simulator:
1. SETUP tab opens SettingsView (no ComingSoonView).
2. Notification permission requested on first SETUP visit (not before).
3. All 6 sections visible and interactive.
4. Toggling notification options reschedules via NotificationCoordinator.
5. Reset Data: scope picker → type RESET → confirm → store wiped.
6. After reset, seed re-creates the HEALTH page on next Today render.

Automated: `xcodebuild test ...` — all 130+ tests pass.

## Out of scope for this plan
Per-habit reminders · Risk alerts (need 6h-ahead scheduling) · CSV export/import · iCloud 30-day snapshot before reset · Widgets · Live Activity · Apple Watch · iPad layouts · Onboarding · Themes · CloudKit cutover · Live Activity.
