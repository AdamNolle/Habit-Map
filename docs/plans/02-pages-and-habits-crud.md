# Habit Map — Plan 02: Pages & Habits CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Users can create, rename, recolor, archive, reorder, and delete pages. Users can add habits via a 3-step wizard, edit them in a detail view, archive, and delete. The Today screen reflects all CRUD changes live. New components (FAB, PixelButton, PixelToggle, EmojiPicker, AccentSwatchPicker) keep the pixel-art aesthetic.

**Architecture:** All persistence operations go through a `HabitRepository` actor that wraps `ModelContext` — gives us a single seam for analytics, validation, and CloudKit conflict resolution later. Views call `@Environment(HabitRepository.self)`. Modal flows use `.sheet { NavigationStack { ... } }` so each flow has its own navigation context. The Today screen and Pages Manager subscribe via `@Query` and re-render on change.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 17+, SwiftData. No new dependencies.

---

## Context

Plan 01 shipped the foundation: SwiftData models, the pixel-art design system, and a Today screen with one seeded habit. Plan 02 makes the app actually usable as a multi-page habit tracker: users can author their own pages and habits.

**Scope boundary:** Habit types in this plan are `.manualOnce` and `.manualMultiple` only. `.autoHealth` requires HealthKit (Plan 03). `.inverse` is a small UI surface that can land here cheaply — including. Reminders are stored on the `Habit` model but **not yet scheduled with `UNUserNotificationCenter`** (notifications land in Plan 06). The wizard accepts a reminder time and persists it; nothing fires yet.

**Decisions from the handoff doc:**
- Habit creation = 3-step wizard
- Page reorder = native `List.onMove` inside a long-press edit mode
- CloudKit stays off (no team ID yet)
- Light mode deferred to Plan 06

---

## File Structure (new additions)

```
Packages/HabitMapCore/
  Sources/HabitMapCore/
    Components/
      PixelButton.swift               # primary / secondary / destructive variants
      PixelToggle.swift               # on/off pixel-art switch
      FAB.swift                       # bottom-right floating button
      EmojiPicker.swift               # grid-based emoji selector
      AccentSwatchPicker.swift        # 9-swatch grid (DesignTokens.Accent.*)
      WeekdayPicker.swift             # MTWTFSS pixel toggles
    Services/
      HabitRepository.swift           # actor wrapping ModelContext
    Persistence/
      SeedData.swift                  # (modified) seed now optional/dev-only
  Tests/HabitMapCoreTests/
    PixelButtonSnapshotTests.swift
    PixelToggleSnapshotTests.swift
    FABSnapshotTests.swift
    EmojiPickerTests.swift
    AccentSwatchPickerSnapshotTests.swift
    WeekdayPickerSnapshotTests.swift
    HabitRepositoryTests.swift        # repo CRUD + page migration logic

Apps/iOS/HabitMap/
  Screens/
    Pages/
      PagesManagerView.swift          # list + reorder + archive + delete
      AddPageSheet.swift              # create-new-page modal
      EditPageSheet.swift             # rename + recolor existing page
    Habit/
      AddHabitWizardView.swift        # 3-step wizard host
      AddHabitStep1View.swift         # emoji + name
      AddHabitStep2View.swift         # type + target reps
      AddHabitStep3View.swift         # schedule + reminder
      HabitDetailView.swift           # PixelRing + edit + archive + delete
  Components/
      WizardProgressBar.swift         # 3 pixel-dots step indicator
  Modified:
    Screens/Today/TabBar.swift        # plus icon becomes FAB trigger
    Screens/Today/HeaderView.swift    # grid icon → tap opens PagesManagerView
    Screens/Today/HabitRow.swift      # long-press → open HabitDetailView
HabitMapApp.swift                     # inject HabitRepository
HabitMapUITests/
  PageCRUDUITests.swift
  HabitWizardUITests.swift
```

---

## Task 1: PixelButton — primary / secondary / destructive variants

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/PixelButton.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/PixelButtonSnapshotTests.swift`

- [ ] **Step 1: Write `PixelButton.swift`**

```swift
import SwiftUI

public enum PixelButtonStyle: Sendable {
    case primary       // accent fill, dark text
    case secondary     // dark fill, accent text, accent border
    case destructive   // miss-red fill, white text
}

public struct PixelButton: View {
    let title: String
    let style: PixelButtonStyle
    let accent: Color
    let action: () -> Void
    let isEnabled: Bool

    public init(_ title: String,
                style: PixelButtonStyle = .primary,
                accent: Color = DesignTokens.Accent.classicGreen,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.accent = accent
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: { if isEnabled { action() } }) {
            PixelText(title, pixelSize: 3, color: textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(fillColor)
                .overlay(Rectangle().stroke(borderColor, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.4)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private var fillColor: Color {
        switch style {
        case .primary:     return accent
        case .secondary:   return DesignTokens.Surface.card
        case .destructive: return DesignTokens.Surface.miss
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:     return Color.black
        case .secondary:   return accent
        case .destructive: return Color.white
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:     return accent.darker(by: 0.2)
        case .secondary:   return accent
        case .destructive: return DesignTokens.Surface.miss.darker(by: 0.2)
        }
    }
}
```

- [ ] **Step 2: Write `PixelButtonSnapshotTests.swift`**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelButtonSnapshotTests: XCTestCase {
    private func host<V: View>(_ view: V) -> some View {
        view.padding(16).background(Color.black).fixedSize()
    }

    func test_primary() {
        assertSnapshot(of: host(PixelButton("SAVE", style: .primary) {}),
                       as: .image(precision: 0.99))
    }
    func test_secondary() {
        assertSnapshot(of: host(PixelButton("CANCEL", style: .secondary) {}),
                       as: .image(precision: 0.99))
    }
    func test_destructive() {
        assertSnapshot(of: host(PixelButton("DELETE", style: .destructive) {}),
                       as: .image(precision: 0.99))
    }
    func test_disabled() {
        assertSnapshot(of: host(PixelButton("NEXT", isEnabled: false) {}),
                       as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Run + record snapshots, eyeball each, commit**

```bash
xcodegen generate
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
    -only-testing:HabitMapCoreTests/PixelButtonSnapshotTests
```
First run records baselines, second run passes. Visually verify primary is filled, secondary is outlined, destructive is red, disabled is faded.

```bash
git add Packages/HabitMapCore HabitMap.xcodeproj
git commit -m "feat(components): add PixelButton with 3 styles + disabled state"
```

---

## Task 2: PixelToggle — on/off switch

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/PixelToggle.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/PixelToggleSnapshotTests.swift`

- [ ] **Step 1: Write `PixelToggle.swift`**

```swift
import SwiftUI

public struct PixelToggle: View {
    @Binding var isOn: Bool
    let accent: Color

    public init(isOn: Binding<Bool>, accent: Color = DesignTokens.Accent.classicGreen) {
        self._isOn = isOn
        self.accent = accent
    }

    public var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn ? accent.darker(by: 0.2) : DesignTokens.Surface.tile)
                    .overlay(Rectangle().stroke(isOn ? accent : DesignTokens.Surface.tileBorder, lineWidth: 2))
                    .frame(width: 44, height: 24)
                Rectangle()
                    .fill(isOn ? accent : DesignTokens.Surface.inactive)
                    .frame(width: 16, height: 16)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 2: Write `PixelToggleSnapshotTests.swift`**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelToggleSnapshotTests: XCTestCase {
    func test_off() {
        var off = false
        let view = PixelToggle(isOn: .constant(off))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
    func test_on() {
        let view = PixelToggle(isOn: .constant(true))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Run, verify, commit**

```bash
git commit -m "feat(components): add PixelToggle for on/off settings"
```

---

## Task 3: FAB (floating action button)

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/FAB.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/FABSnapshotTests.swift`

- [ ] **Step 1: Write `FAB.swift`**

```swift
import SwiftUI

public struct FAB: View {
    let accent: Color
    let action: () -> Void

    public init(accent: Color = DesignTokens.Accent.classicGreen,
                action: @escaping () -> Void) {
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            PixelIcon(.plus, color: .black, size: 28)
                .frame(width: 56, height: 56)
                .background(accent)
                .overlay(Rectangle().stroke(accent.darker(by: 0.2), lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add habit")
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 2: Snapshot test**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class FABSnapshotTests: XCTestCase {
    func test_fab() {
        let view = FAB { }
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add FAB plus-button"
```

---

## Task 4: AccentSwatchPicker — 9-color grid

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/AccentSwatchPicker.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/AccentSwatchPickerSnapshotTests.swift`

- [ ] **Step 1: Write `AccentSwatchPicker.swift`**

```swift
import SwiftUI

public struct AccentSwatchPicker: View {
    @Binding var selectedHex: String

    public static let swatches: [String] = [
        "#2BFF5F", "#C8FF2B", "#3DA4FF",
        "#FFB23D", "#C77BFF", "#FF6B9A",
        "#7EE6FF", "#0072B2", "#E69F00"
    ]

    public init(selectedHex: Binding<String>) {
        self._selectedHex = selectedHex
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Self.swatches, id: \.self) { hex in
                let color = Color(hex: hex)
                Button(action: { selectedHex = hex }) {
                    Rectangle()
                        .fill(color)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Rectangle()
                                .stroke(selectedHex == hex ? Color.white : color.darker(by: 0.25),
                                        lineWidth: selectedHex == hex ? 3 : 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityAddTraits(selectedHex == hex ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
```

- [ ] **Step 2: Snapshot test**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class AccentSwatchPickerSnapshotTests: XCTestCase {
    func test_picker_default() {
        let view = AccentSwatchPicker(selectedHex: .constant("#2BFF5F"))
            .frame(width: 240)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
    func test_swatch_count() {
        XCTAssertEqual(AccentSwatchPicker.swatches.count, 9)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add AccentSwatchPicker with 9 palette colors"
```

---

## Task 5: EmojiPicker — grid of curated emoji

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/EmojiPicker.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/EmojiPickerTests.swift`

The full Apple emoji picker is overkill. Ship a curated list of ~64 habit-relevant emoji organized in a single scrollable grid.

- [ ] **Step 1: Write `EmojiPicker.swift`**

```swift
import SwiftUI

public struct EmojiPicker: View {
    @Binding var selected: String
    let accent: Color

    public static let catalog: [String] = [
        // Health
        "💧", "🏃", "🚶", "🧘", "🏋️", "🚴", "🏊", "🥗",
        "🍎", "🥦", "💊", "🧴", "🦷", "💤", "🛏️", "☀️",
        // Mind
        "📖", "✍️", "🧠", "🎯", "💭", "🕯️", "🎨", "🎵",
        // Work
        "💻", "📧", "📞", "📊", "📁", "✅", "🗓️", "⏰",
        // Home
        "🧹", "🍽️", "🧺", "🪴", "🐕", "🐈", "👨‍👩‍👧", "💌",
        // Fun
        "🎮", "🎬", "🎤", "🎉", "🎸", "🧩", "📷", "✈️",
        // Vices
        "🚬", "🍷", "🥤", "🍰", "📱", "📺", "🛍️", "🎰",
        // Generic
        "⭐", "❤️", "🔥", "💎", "🏆", "🌱", "🌊", "🌙"
    ]

    public init(selected: Binding<String>, accent: Color = DesignTokens.Accent.classicGreen) {
        self._selected = selected
        self.accent = accent
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(Self.catalog, id: \.self) { emoji in
                Button(action: { selected = emoji }) {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 36, height: 36)
                        .background(selected == emoji ? accent.darker(by: 0.4) : DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(selected == emoji ? accent : DesignTokens.Surface.tileBorder,
                                                   lineWidth: selected == emoji ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emoji)
                .accessibilityAddTraits(selected == emoji ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
```

- [ ] **Step 2: Unit test (no snapshot — emoji rendering varies by system font)**

```swift
import XCTest
@testable import HabitMapCore

final class EmojiPickerTests: XCTestCase {
    func test_catalogHasExpectedCount() {
        XCTAssertEqual(EmojiPicker.catalog.count, 64)
    }

    func test_catalogIsDeduplicated() {
        let unique = Set(EmojiPicker.catalog)
        XCTAssertEqual(unique.count, EmojiPicker.catalog.count, "Catalog has duplicate emoji")
    }

    func test_catalogContainsCommonHabits() {
        XCTAssertTrue(EmojiPicker.catalog.contains("💧"))
        XCTAssertTrue(EmojiPicker.catalog.contains("🏃"))
        XCTAssertTrue(EmojiPicker.catalog.contains("🧘"))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add curated 64-emoji EmojiPicker"
```

---

## Task 6: WeekdayPicker — pixel-art MTWTFSS toggle row

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Components/WeekdayPicker.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/WeekdayPickerSnapshotTests.swift`

- [ ] **Step 1: Write `WeekdayPicker.swift`**

```swift
import SwiftUI

public struct WeekdayPicker: View {
    /// bit 0 = Mon ... bit 6 = Sun
    @Binding var mask: Int8
    let accent: Color
    let labels: [String] = ["M", "T", "W", "T", "F", "S", "S"]

    public init(mask: Binding<Int8>, accent: Color = DesignTokens.Accent.classicGreen) {
        self._mask = mask
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                let bit = Int8(1 << idx)
                let isOn = (mask & bit) != 0
                Button(action: { mask ^= bit }) {
                    PixelText(labels[idx], pixelSize: 2, color: isOn ? .black : accent)
                        .frame(width: 28, height: 28)
                        .background(isOn ? accent : DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(isOn ? accent.darker(by: 0.2) : DesignTokens.Surface.tileBorder,
                                                   lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][idx])")
                .accessibilityValue(isOn ? "selected" : "not selected")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
```

- [ ] **Step 2: Tests**

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class WeekdayPickerSnapshotTests: XCTestCase {
    func test_allOn() {
        let view = WeekdayPicker(mask: .constant(0b01111111))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_weekdaysOnly() {
        // Mon-Fri (Mon=bit0, Tue=bit1, Wed=bit2, Thu=bit3, Fri=bit4 → 0b00011111)
        let view = WeekdayPicker(mask: .constant(0b00011111))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_noneSelected() {
        let view = WeekdayPicker(mask: .constant(0))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(components): add WeekdayPicker with pixel-art MTWTFSS toggles"
```

---

## Task 7: HabitRepository — actor-wrapped persistence layer

**Files:**
- Create: `Packages/HabitMapCore/Sources/HabitMapCore/Services/HabitRepository.swift`
- Create: `Packages/HabitMapCore/Tests/HabitMapCoreTests/HabitRepositoryTests.swift`

- [ ] **Step 1: Write `HabitRepository.swift`**

```swift
import Foundation
import SwiftData

@MainActor
public final class HabitRepository: ObservableObject {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Pages

    @discardableResult
    public func createPage(name: String, emoji: String, accentHex: String) throws -> HabitPage {
        let nextSort = (try fetchPages().map(\.sortOrder).max() ?? -1) + 1
        let page = HabitPage(name: name.uppercased(), emoji: emoji, accentHex: accentHex, sortOrder: nextSort)
        context.insert(page)
        try context.save()
        return page
    }

    public func updatePage(_ page: HabitPage, name: String? = nil, emoji: String? = nil, accentHex: String? = nil) throws {
        if let name { page.name = name.uppercased() }
        if let emoji { page.emoji = emoji }
        if let accentHex { page.accentHex = accentHex }
        try context.save()
    }

    public func reorderPages(_ ordered: [HabitPage]) throws {
        for (idx, page) in ordered.enumerated() { page.sortOrder = idx }
        try context.save()
    }

    public func archivePage(_ page: HabitPage) throws {
        page.isArchived = true
        try context.save()
    }

    /// Delete a page. If the page has habits and `migrateTo` is nil, fail. Otherwise move habits to target page.
    public func deletePage(_ page: HabitPage, migrateTo target: HabitPage? = nil) throws {
        let habits = page.habits ?? []
        if !habits.isEmpty {
            guard let target else {
                throw HabitRepositoryError.pageHasHabitsRequireMigration(count: habits.count)
            }
            for habit in habits { habit.page = target }
        }
        context.delete(page)
        try context.save()
    }

    public func fetchPages(includeArchived: Bool = false) throws -> [HabitPage] {
        let pred = #Predicate<HabitPage> { includeArchived || !$0.isArchived }
        let descriptor = FetchDescriptor<HabitPage>(predicate: pred, sortBy: [SortDescriptor(\.sortOrder)])
        return try context.fetch(descriptor)
    }

    // MARK: - Habits

    @discardableResult
    public func createHabit(name: String,
                            emoji: String,
                            accentHex: String,
                            type: HabitType,
                            targetReps: Int,
                            weekdayMask: Int8,
                            restDayMask: Int8 = 0,
                            reminderTime: Date? = nil,
                            on page: HabitPage) throws -> Habit {
        let nextSort = ((page.habits ?? []).map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(name: name.uppercased(),
                          emoji: emoji,
                          accentHex: accentHex,
                          type: type,
                          targetReps: targetReps,
                          weekdayMask: weekdayMask,
                          restDayMask: restDayMask,
                          sortOrder: nextSort,
                          page: page)
        habit.reminderTime = reminderTime
        context.insert(habit)
        try context.save()
        return habit
    }

    public func updateHabit(_ habit: Habit,
                            name: String? = nil,
                            emoji: String? = nil,
                            accentHex: String? = nil,
                            targetReps: Int? = nil,
                            weekdayMask: Int8? = nil,
                            restDayMask: Int8? = nil,
                            reminderTime: Date?? = nil,
                            page: HabitPage? = nil) throws {
        if let name { habit.name = name.uppercased() }
        if let emoji { habit.emoji = emoji }
        if let accentHex { habit.accentHex = accentHex }
        if let targetReps { habit.targetReps = targetReps }
        if let weekdayMask { habit.weekdayMask = weekdayMask }
        if let restDayMask { habit.restDayMask = restDayMask }
        if let reminderTime { habit.reminderTime = reminderTime }
        if let page { habit.page = page }
        try context.save()
    }

    public func archiveHabit(_ habit: Habit) throws {
        habit.isArchived = true
        try context.save()
    }

    public func deleteHabit(_ habit: Habit) throws {
        context.delete(habit)
        try context.save()
    }

    public func reorderHabits(_ ordered: [Habit]) throws {
        for (idx, habit) in ordered.enumerated() { habit.sortOrder = idx }
        try context.save()
    }
}

public enum HabitRepositoryError: LocalizedError {
    case pageHasHabitsRequireMigration(count: Int)

    public var errorDescription: String? {
        switch self {
        case .pageHasHabitsRequireMigration(let n):
            return "Cannot delete page with \(n) habit\(n == 1 ? "" : "s"). Choose a destination page first."
        }
    }
}
```

- [ ] **Step 2: Write `HabitRepositoryTests.swift`**

```swift
import XCTest
import SwiftData
@testable import HabitMapCore

final class HabitRepositoryTests: XCTestCase {
    var container: ModelContainer!
    var repo: HabitRepository!

    @MainActor
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: config
        )
        repo = HabitRepository(context: container.mainContext)
    }

    @MainActor
    func test_createPage_assignsNextSortOrder() throws {
        _ = try repo.createPage(name: "Health", emoji: "🩺", accentHex: "#2BFF5F")
        let second = try repo.createPage(name: "Work", emoji: "💻", accentHex: "#3DA4FF")
        XCTAssertEqual(second.sortOrder, 1)
    }

    @MainActor
    func test_createPage_uppercasesName() throws {
        let page = try repo.createPage(name: "health", emoji: "🩺", accentHex: "#2BFF5F")
        XCTAssertEqual(page.name, "HEALTH")
    }

    @MainActor
    func test_updatePage_modifiesFields() throws {
        let page = try repo.createPage(name: "Health", emoji: "🩺", accentHex: "#2BFF5F")
        try repo.updatePage(page, name: "wellness", emoji: "🌿", accentHex: "#C8FF2B")
        XCTAssertEqual(page.name, "WELLNESS")
        XCTAssertEqual(page.emoji, "🌿")
        XCTAssertEqual(page.accentHex, "#C8FF2B")
    }

    @MainActor
    func test_reorderPages_assignsSequentialIndices() throws {
        let a = try repo.createPage(name: "A", emoji: "🅰", accentHex: "#2BFF5F")
        let b = try repo.createPage(name: "B", emoji: "🅱", accentHex: "#3DA4FF")
        let c = try repo.createPage(name: "C", emoji: "🇨", accentHex: "#FFB23D")
        try repo.reorderPages([c, a, b])
        XCTAssertEqual(c.sortOrder, 0)
        XCTAssertEqual(a.sortOrder, 1)
        XCTAssertEqual(b.sortOrder, 2)
    }

    @MainActor
    func test_deletePage_emptyPage_succeeds() throws {
        let page = try repo.createPage(name: "Empty", emoji: "🗑", accentHex: "#2BFF5F")
        try repo.deletePage(page)
        XCTAssertEqual(try repo.fetchPages().count, 0)
    }

    @MainActor
    func test_deletePage_withHabits_requiresMigration() throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        _ = try repo.createHabit(name: "H", emoji: "💧", accentHex: "#3DA4FF",
                                 type: .manualOnce, targetReps: 1,
                                 weekdayMask: 0b01111111, on: page)
        XCTAssertThrowsError(try repo.deletePage(page))
    }

    @MainActor
    func test_deletePage_withHabits_migratesToTarget() throws {
        let src = try repo.createPage(name: "SRC", emoji: "🅰", accentHex: "#2BFF5F")
        let dst = try repo.createPage(name: "DST", emoji: "🅱", accentHex: "#3DA4FF")
        let habit = try repo.createHabit(name: "H", emoji: "💧", accentHex: "#3DA4FF",
                                         type: .manualOnce, targetReps: 1,
                                         weekdayMask: 0b01111111, on: src)
        try repo.deletePage(src, migrateTo: dst)
        XCTAssertEqual(habit.page?.id, dst.id)
        XCTAssertEqual(try repo.fetchPages().count, 1)
    }

    @MainActor
    func test_createHabit_appliesAllFields() throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let reminder = Date()
        let habit = try repo.createHabit(name: "drink water", emoji: "💧",
                                         accentHex: "#3DA4FF",
                                         type: .manualMultiple, targetReps: 4,
                                         weekdayMask: 0b00011111,
                                         restDayMask: 0,
                                         reminderTime: reminder,
                                         on: page)
        XCTAssertEqual(habit.name, "DRINK WATER")
        XCTAssertEqual(habit.targetReps, 4)
        XCTAssertEqual(habit.weekdayMask, 0b00011111)
        XCTAssertNotNil(habit.reminderTime)
        XCTAssertEqual(habit.page?.id, page.id)
    }

    @MainActor
    func test_archiveHabit_marksField() throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "H", emoji: "💧", accentHex: "#3DA4FF",
                                         type: .manualOnce, targetReps: 1,
                                         weekdayMask: 0b01111111, on: page)
        try repo.archiveHabit(habit)
        XCTAssertTrue(habit.isArchived)
    }

    @MainActor
    func test_deleteHabit_removes() throws {
        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "H", emoji: "💧", accentHex: "#3DA4FF",
                                         type: .manualOnce, targetReps: 1,
                                         weekdayMask: 0b01111111, on: page)
        try repo.deleteHabit(habit)
        XCTAssertEqual((page.habits ?? []).count, 0)
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
git commit -m "feat(services): add HabitRepository actor for pages/habits CRUD"
```

---

## Task 8: Pages Manager screen

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Pages/PagesManagerView.swift`
- Create: `Apps/iOS/HabitMap/Screens/Pages/AddPageSheet.swift`
- Create: `Apps/iOS/HabitMap/Screens/Pages/EditPageSheet.swift`
- Modify: `Apps/iOS/HabitMap/Screens/Today/HeaderView.swift` — grid icon opens manager

- [ ] **Step 1: Write `AddPageSheet.swift`**

```swift
import SwiftUI
import HabitMapCore

struct AddPageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository

    @State private var name: String = ""
    @State private var emoji: String = "🩺"
    @State private var accentHex: String = "#2BFF5F"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    Section(title: "NAME") {
                        TextField("e.g. HEALTH", text: $name)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced).weight(.heavy))
                            .padding(12)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                    }
                    Section(title: "EMOJI") {
                        EmojiPicker(selected: $emoji, accent: Color(hex: accentHex))
                    }
                    Section(title: "ACCENT") {
                        AccentSwatchPicker(selectedHex: $accentHex)
                    }
                    PixelButton("CREATE PAGE",
                                style: .primary,
                                accent: Color(hex: accentHex),
                                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        do {
                            try repo.createPage(name: name, emoji: emoji, accentHex: accentHex)
                            dismiss()
                        } catch { print("Create page failed: \(error)") }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("NEW PAGE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func Section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelText(title, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            content()
        }
    }
}
```

- [ ] **Step 2: Write `EditPageSheet.swift`**

```swift
import SwiftUI
import HabitMapCore

struct EditPageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @Bindable var page: HabitPage

    @State private var name: String
    @State private var emoji: String
    @State private var accentHex: String

    init(page: HabitPage) {
        self.page = page
        self._name = State(initialValue: page.name)
        self._emoji = State(initialValue: page.emoji)
        self._accentHex = State(initialValue: page.accentHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    Section(title: "NAME") {
                        TextField("name", text: $name)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced).weight(.heavy))
                            .padding(12)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                    }
                    Section(title: "EMOJI") {
                        EmojiPicker(selected: $emoji, accent: Color(hex: accentHex))
                    }
                    Section(title: "ACCENT") {
                        AccentSwatchPicker(selectedHex: $accentHex)
                    }
                    PixelButton("SAVE",
                                accent: Color(hex: accentHex),
                                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        do {
                            try repo.updatePage(page, name: name, emoji: emoji, accentHex: accentHex)
                            dismiss()
                        } catch { print("Update page failed: \(error)") }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("EDIT PAGE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func Section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelText(title, pixelSize: 2, color: DesignTokens.Surface.mutedText)
            content()
        }
    }
}
```

- [ ] **Step 3: Write `PagesManagerView.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

struct PagesManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @Query(filter: #Predicate<HabitPage> { !$0.isArchived },
           sort: \HabitPage.sortOrder) private var activePages: [HabitPage]
    @Query(filter: #Predicate<HabitPage> { $0.isArchived },
           sort: \HabitPage.sortOrder) private var archivedPages: [HabitPage]

    @State private var showAddSheet = false
    @State private var editingPage: HabitPage?
    @State private var deletingPage: HabitPage?
    @State private var migrationTarget: HabitPage?

    var body: some View {
        NavigationStack {
            List {
                Section("ACTIVE") {
                    ForEach(activePages) { page in
                        pageRow(page)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: requestDelete)
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack {
                            PixelIcon(.plus, color: DesignTokens.Accent.classicGreen, size: 18)
                            PixelText("NEW PAGE", pixelSize: 2, color: DesignTokens.Accent.classicGreen)
                        }
                    }
                    .accessibilityLabel("Add page")
                }
                if !archivedPages.isEmpty {
                    Section("ARCHIVED") {
                        ForEach(archivedPages) { page in
                            pageRow(page).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Surface.bg)
            .navigationTitle("PAGES")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .sheet(isPresented: $showAddSheet) {
                AddPageSheet().environmentObject(repo)
            }
            .sheet(item: $editingPage) { page in
                EditPageSheet(page: page).environmentObject(repo)
            }
            .alert("Delete page?",
                   isPresented: Binding(get: { deletingPage != nil },
                                        set: { if !$0 { deletingPage = nil } }),
                   presenting: deletingPage) { page in
                let habits = (page.habits ?? []).count
                if habits > 0 {
                    Button("Delete & migrate to first other page", role: .destructive) {
                        let other = activePages.first { $0.id != page.id }
                        if let other {
                            try? repo.deletePage(page, migrateTo: other)
                        }
                        deletingPage = nil
                    }
                    Button("Archive instead") {
                        try? repo.archivePage(page)
                        deletingPage = nil
                    }
                    Button("Cancel", role: .cancel) { deletingPage = nil }
                } else {
                    Button("Delete", role: .destructive) {
                        try? repo.deletePage(page)
                        deletingPage = nil
                    }
                    Button("Cancel", role: .cancel) { deletingPage = nil }
                }
            } message: { page in
                let n = (page.habits ?? []).count
                if n > 0 {
                    Text("This page has \(n) habit\(n == 1 ? "" : "s"). Migrate them to another page or archive this page instead.")
                } else {
                    Text("This action is permanent.")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func pageRow(_ page: HabitPage) -> some View {
        HStack {
            Text(page.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                PixelText(page.name, pixelSize: 2, color: page.accentColor)
                    .accessibilityLabel(page.name)
                Text("\((page.habits ?? []).count) HABITS")
                    .font(.system(.caption2, design: .monospaced).weight(.heavy))
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Spacer()
            Rectangle()
                .fill(page.accentColor)
                .frame(width: 12, height: 12)
                .overlay(Rectangle().stroke(.black, lineWidth: 1))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { editingPage = page }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = activePages
        reordered.move(fromOffsets: source, toOffset: destination)
        try? repo.reorderPages(reordered)
    }

    private func requestDelete(at offsets: IndexSet) {
        for idx in offsets { deletingPage = activePages[idx] }
    }
}
```

- [ ] **Step 4: Modify `HeaderView.swift` — grid icon opens manager**

Replace the existing `PixelIcon(.grid, ...)` with a Button:

```swift
@State private var showPages = false

// ... in body
Button { showPages = true } label: {
    PixelIcon(.grid, color: DesignTokens.Surface.mutedText, size: 24)
}
.accessibilityLabel("Manage pages")
.sheet(isPresented: $showPages) {
    PagesManagerView()
}
```

- [ ] **Step 5: Test, commit**

Manual smoke: open the manager, add a page, rename it, archive it, delete an empty page. All should persist.

```bash
git commit -m "feat(pages): add PagesManagerView + Add/Edit sheets, wired into header"
```

---

## Task 9: Habit Creation Wizard (3 steps)

**Files:**
- Create: `Apps/iOS/HabitMap/Components/WizardProgressBar.swift`
- Create: `Apps/iOS/HabitMap/Screens/Habit/AddHabitStep1View.swift`
- Create: `Apps/iOS/HabitMap/Screens/Habit/AddHabitStep2View.swift`
- Create: `Apps/iOS/HabitMap/Screens/Habit/AddHabitStep3View.swift`
- Create: `Apps/iOS/HabitMap/Screens/Habit/AddHabitWizardView.swift`

- [ ] **Step 1: Write `WizardProgressBar.swift`**

```swift
import SwiftUI
import HabitMapCore

struct WizardProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Rectangle()
                    .fill(idx == currentStep
                          ? accent
                          : (idx < currentStep ? accent.darker(by: 0.4) : DesignTokens.Surface.dotInactive))
                    .frame(height: 6)
                    .overlay(Rectangle().stroke(.black, lineWidth: 1))
            }
        }
    }
}
```

- [ ] **Step 2: Write the wizard state container `AddHabitWizardView.swift`**

```swift
import SwiftUI
import HabitMapCore

struct WizardDraft {
    var name: String = ""
    var emoji: String = "💧"
    var accentHex: String = "#3DA4FF"
    var type: HabitType = .manualMultiple
    var targetReps: Int = 1
    var weekdayMask: Int8 = 0b01111111
    var restDayMask: Int8 = 0
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
}

struct AddHabitWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    let page: HabitPage

    @State private var step: Int = 0
    @State private var draft = WizardDraft()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WizardProgressBar(currentStep: step, totalSteps: 3, accent: page.accentColor)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.md)

                ScrollView {
                    Group {
                        switch step {
                        case 0: AddHabitStep1View(draft: $draft, pageAccent: page.accentColor)
                        case 1: AddHabitStep2View(draft: $draft, pageAccent: page.accentColor)
                        default: AddHabitStep3View(draft: $draft, pageAccent: page.accentColor)
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    if step > 0 {
                        PixelButton("BACK", style: .secondary, accent: page.accentColor) { step -= 1 }
                    }
                    PixelButton(step == 2 ? "CREATE" : "NEXT",
                                accent: page.accentColor,
                                isEnabled: canAdvance) {
                        if step < 2 { step += 1 } else { create() }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("NEW HABIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return draft.targetReps >= 1 || draft.type == .inverse || draft.type == .manualOnce
        default: return draft.weekdayMask != 0
        }
    }

    private func create() {
        let reps: Int
        switch draft.type {
        case .manualOnce: reps = 1
        case .inverse: reps = 0
        case .manualMultiple, .autoHealth: reps = draft.targetReps
        }
        try? repo.createHabit(name: draft.name,
                              emoji: draft.emoji,
                              accentHex: draft.accentHex,
                              type: draft.type,
                              targetReps: reps,
                              weekdayMask: draft.weekdayMask,
                              restDayMask: draft.restDayMask,
                              reminderTime: draft.reminderEnabled ? draft.reminderTime : nil,
                              on: page)
        dismiss()
    }
}
```

- [ ] **Step 3: Write `AddHabitStep1View.swift`**

```swift
import SwiftUI
import HabitMapCore

struct AddHabitStep1View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            PixelText("STEP 1 - WHAT", pixelSize: 2, color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 10) {
                PixelText("NAME", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                TextField("e.g. DRINK WATER", text: $draft.name)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.body, design: .monospaced).weight(.heavy))
                    .padding(12)
                    .background(DesignTokens.Surface.tile)
                    .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 10) {
                PixelText("EMOJI", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                EmojiPicker(selected: $draft.emoji, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 10) {
                PixelText("ACCENT", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                AccentSwatchPicker(selectedHex: $draft.accentHex)
            }
        }
    }
}
```

- [ ] **Step 4: Write `AddHabitStep2View.swift`**

```swift
import SwiftUI
import HabitMapCore

struct AddHabitStep2View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            PixelText("STEP 2 - HOW OFTEN", pixelSize: 2, color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 12) {
                PixelText("TYPE", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                typeRow(.manualOnce, label: "ONCE A DAY", subtitle: "Tap once when done")
                typeRow(.manualMultiple, label: "MULTIPLE TIMES", subtitle: "Tap N times to hit target")
                typeRow(.inverse, label: "AVOID", subtitle: "Default complete unless slipped")
            }

            if draft.type == .manualMultiple {
                VStack(alignment: .leading, spacing: 10) {
                    PixelText("TARGET REPS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                    HStack(spacing: DesignTokens.Spacing.md) {
                        PixelButton("-", style: .secondary, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = max(1, draft.targetReps - 1)
                        }.frame(width: 60)
                        PixelText("\(draft.targetReps)", pixelSize: 6, color: Color(hex: draft.accentHex))
                            .frame(maxWidth: .infinity)
                        PixelButton("+", style: .secondary, accent: Color(hex: draft.accentHex)) {
                            draft.targetReps = min(20, draft.targetReps + 1)
                        }.frame(width: 60)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func typeRow(_ type: HabitType, label: String, subtitle: String) -> some View {
        Button { draft.type = type } label: {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(draft.type == type ? Color(hex: draft.accentHex) : DesignTokens.Surface.inactive)
                    .frame(width: 18, height: 18)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    PixelText(label, pixelSize: 2, color: Color(hex: draft.accentHex))
                    Text(subtitle)
                        .font(.system(.caption2, design: .monospaced).weight(.heavy))
                        .tracking(1.0)
                        .foregroundColor(DesignTokens.Surface.mutedText)
                }
                Spacer()
            }
            .padding(12)
            .background(DesignTokens.Surface.card)
            .overlay(Rectangle().stroke(draft.type == type ? Color(hex: draft.accentHex) : DesignTokens.Surface.cardBorder,
                                       lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(draft.type == type ? [.isButton, .isSelected] : .isButton)
    }
}
```

- [ ] **Step 5: Write `AddHabitStep3View.swift`**

```swift
import SwiftUI
import HabitMapCore

struct AddHabitStep3View: View {
    @Binding var draft: WizardDraft
    let pageAccent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            PixelText("STEP 3 - WHEN", pixelSize: 2, color: DesignTokens.Surface.mutedText)

            VStack(alignment: .leading, spacing: 10) {
                PixelText("DAYS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                WeekdayPicker(mask: $draft.weekdayMask, accent: Color(hex: draft.accentHex))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PixelText("REMINDER", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                    Spacer()
                    PixelToggle(isOn: $draft.reminderEnabled, accent: Color(hex: draft.accentHex))
                }
                if draft.reminderEnabled {
                    DatePicker("",
                               selection: $draft.reminderTime,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .background(DesignTokens.Surface.tile)
                        .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                }
            }
        }
    }
}
```

- [ ] **Step 6: Wire FAB into TabBar's plus slot**

Modify `TabBar.swift` to expose an "onAddTapped" callback, or — simpler — switch the tab bar from 4 to 4 items + center FAB. Cleanest: keep the 4-tab bar and add a separate floating FAB anchored bottom-right in `TodayView`.

In `TodayView.swift`, after the VStack containing PageDots + TabBar, add:

```swift
.overlay(alignment: .bottomTrailing) {
    if let id = selectedPageID,
       let page = pages.first(where: { $0.id == id }) {
        FAB(accent: page.accentColor) { wizardPage = page }
            .padding(.trailing, DesignTokens.Spacing.lg)
            .padding(.bottom, 96)   // clear the tab bar
            .accessibilityLabel("Add habit to \(page.name)")
    }
}
.sheet(item: $wizardPage) { page in
    AddHabitWizardView(page: page).environmentObject(repo)
}
```

And add `@State private var wizardPage: HabitPage?` plus `@EnvironmentObject private var repo: HabitRepository`.

- [ ] **Step 7: Manual smoke test + commit**

```bash
git commit -m "feat(habit): add 3-step habit creation wizard with FAB entry"
```

---

## Task 10: Habit Detail screen + edit/archive/delete

**Files:**
- Create: `Apps/iOS/HabitMap/Screens/Habit/HabitDetailView.swift`
- Modify: `Apps/iOS/HabitMap/Screens/Today/HabitRow.swift` — long-press opens detail

- [ ] **Step 1: Write `HabitDetailView.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: HabitRepository
    @Bindable var habit: Habit

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    // Big ring
                    HStack {
                        Spacer()
                        PixelRing(filledSegments: PixelRing.segments(for: habit.progressFraction(on: Date())),
                                  accent: habit.accentColor)
                            .frame(width: 200, height: 200)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        PixelText("NAME", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        TextField("name", text: $habit.name)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.body, design: .monospaced).weight(.heavy))
                            .padding(12)
                            .background(DesignTokens.Surface.tile)
                            .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        PixelText("EMOJI", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        EmojiPicker(selected: $habit.emoji, accent: habit.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        PixelText("ACCENT", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        AccentSwatchPicker(selectedHex: $habit.accentHex)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        PixelText("DAYS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                        WeekdayPicker(mask: $habit.weekdayMask, accent: habit.accentColor)
                    }

                    if habit.type == .manualMultiple {
                        VStack(alignment: .leading, spacing: 10) {
                            PixelText("TARGET REPS", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                            Stepper("\(habit.targetReps)", value: $habit.targetReps, in: 1...20)
                                .padding(12)
                                .background(DesignTokens.Surface.tile)
                                .overlay(Rectangle().stroke(DesignTokens.Surface.tileBorder, lineWidth: 2))
                        }
                    }

                    // Actions
                    VStack(spacing: 12) {
                        if habit.isArchived {
                            PixelButton("UNARCHIVE", style: .secondary, accent: habit.accentColor) {
                                habit.isArchived = false
                                try? repo.context.save()
                            }
                        } else {
                            PixelButton("ARCHIVE", style: .secondary, accent: habit.accentColor) {
                                try? repo.archiveHabit(habit)
                                dismiss()
                            }
                        }
                        PixelButton("DELETE", style: .destructive) { showDeleteAlert = true }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("HABIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? repo.context.save()
                        dismiss()
                    }
                }
            }
            .alert("Delete this habit?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    try? repo.deleteHabit(habit)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All completion history will be permanently removed.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Modify `HabitRow.swift` — long-press opens detail**

Add `@State private var showDetail = false` and:

```swift
.contextMenu {
    Button { showDetail = true } label: { Label("Edit", systemImage: "pencil") }
    Button(role: .destructive) {
        try? modelContext.delete(habit); try? modelContext.save()
    } label: { Label("Delete", systemImage: "trash") }
}
.sheet(isPresented: $showDetail) {
    HabitDetailView(habit: habit)
}
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(habit): add HabitDetailView with edit/archive/delete + context menu on row"
```

---

## Task 11: Wire up HabitRepository as an EnvironmentObject

**Files:**
- Modify: `Apps/iOS/HabitMap/HabitMapApp.swift`

- [ ] **Step 1: Modify `HabitMapApp.swift`**

```swift
import SwiftUI
import SwiftData
import HabitMapCore

@main
struct HabitMapApp: App {
    let container: ModelContainer
    @StateObject private var repo: HabitRepository

    init() {
        do {
            let container = try PersistenceController.makeContainer(enableCloudKit: false)
            self.container = container
            _repo = StateObject(wrappedValue: HabitRepository(context: container.mainContext))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environmentObject(repo)
                .task {
                    do {
                        try await MainActor.run {
                            try PersistenceController.seedIfNeeded(container.mainContext)
                        }
                    } catch {
                        print("Seed failed: \(error)")
                    }
                }
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Add `@EnvironmentObject` to TodayView for FAB target**

(Already covered in Task 9 Step 6 — confirm wiring.)

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(app): inject HabitRepository as EnvironmentObject"
```

---

## Task 12: UI integration tests

**Files:**
- Create: `Apps/iOS/HabitMapUITests/PageCRUDUITests.swift`
- Create: `Apps/iOS/HabitMapUITests/HabitWizardUITests.swift`

- [ ] **Step 1: Write `PageCRUDUITests.swift`**

```swift
import XCTest

final class PageCRUDUITests: XCTestCase {
    func test_openPagesManagerAndAddPage() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap the grid icon in header to open Pages Manager.
        app.buttons["Manage pages"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["PAGES"].waitForExistence(timeout: 5))

        app.buttons["Add page"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["NEW PAGE"].waitForExistence(timeout: 5))

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("WORK")

        app.buttons["CREATE PAGE"].firstMatch.tap()

        // Back to Pages Manager — WORK should appear.
        XCTAssertTrue(app.staticTexts["WORK"].waitForExistence(timeout: 5)
                      || app.descendants(matching: .any)["WORK"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Write `HabitWizardUITests.swift`**

```swift
import XCTest

final class HabitWizardUITests: XCTestCase {
    func test_createHabitViaWizard() throws {
        let app = XCUIApplication()
        app.launch()

        let fab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add habit'")).firstMatch
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()

        XCTAssertTrue(app.navigationBars["NEW HABIT"].waitForExistence(timeout: 5))

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("STRETCH")

        app.buttons["NEXT"].firstMatch.tap()

        // Step 2: select MANUAL ONCE
        let onceRow = app.buttons["ONCE A DAY"].firstMatch
        if onceRow.waitForExistence(timeout: 3) { onceRow.tap() }
        app.buttons["NEXT"].firstMatch.tap()

        // Step 3: create
        app.buttons["CREATE"].firstMatch.tap()

        // Back on Today screen, STRETCH habit appears.
        XCTAssertTrue(app.descendants(matching: .any)["STRETCH"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
git commit -m "test: add page CRUD + habit wizard UI tests"
```

---

## Task 13: Final verification + Plan 03 handoff

- [ ] **Step 1: Full suite must pass**

```bash
xcodebuild test -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```

- [ ] **Step 2: Manual smoke**

Launch on the simulator. Verify:
1. Today screen shows seeded HEALTH page.
2. Tap grid icon in header → Pages Manager opens.
3. Add a page "WORK" with a different color/emoji. Back on Today, swipe right → see WORK page (empty).
4. Tap FAB on WORK page → wizard opens. Create a habit "READ" with manualOnce, M-F only. Back on Today → READ habit appears on WORK page.
5. Tap READ today cell → fills. Long-press the row → context menu shows Edit/Delete. Tap Edit → detail opens, shows 100% PixelRing.
6. Reorder pages via Pages Manager Edit button → reorder persists after relaunch.
7. Delete an empty page from Pages Manager → confirms then removes.

- [ ] **Step 3: Write `docs/plan-02-handoff.md`**

Note any deviations from this plan and any open questions for Plan 03 (HealthKit).

- [ ] **Step 4: Final commit**

```bash
git add docs/
git commit -m "docs: plan 02 complete, handoff to plan 03 (HealthKit)"
```

---

## Verification

End-to-end manual test on iPhone 16 simulator:
1. Add a page via Pages Manager — page appears on Today.
2. Add a habit via wizard — habit appears in the new page's habit list.
3. Tap-to-log on the new habit — cell fills, persists across cold launch.
4. Reorder pages — swipe across pages confirms new order, persists.
5. Edit a habit's name + accent + schedule via detail view — Today reflects changes.
6. Archive vs delete a habit — archived habits are hidden but not deleted; deleted habits remove completion history.
7. Try to delete a page with habits — prompt offers migrate or archive.

Automated: `xcodebuild test ...` — all unit + snapshot + UI tests pass.

## Out of scope for this plan
HealthKit auto-fill · Heat Map screen · Day-detail journal · Insights · Risk Forecast · Notifications scheduling (model field only) · Settings screen · Reset Data flow · Widgets · Live Activity · Apple Watch · iPad layouts · Onboarding · Themes · CloudKit sync (still off).
