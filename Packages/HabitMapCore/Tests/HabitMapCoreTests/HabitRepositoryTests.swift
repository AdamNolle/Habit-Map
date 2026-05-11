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
