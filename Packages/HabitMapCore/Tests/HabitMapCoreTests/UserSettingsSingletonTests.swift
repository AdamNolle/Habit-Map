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
    func test_defaultPageId_roundTrips() throws {
        let ctx = container.mainContext
        let settings = try UserSettings.fetchOrCreate(in: ctx)
        let pageID = UUID()
        settings.defaultPageId = pageID
        try ctx.save()

        let again = try UserSettings.fetchOrCreate(in: ctx)
        XCTAssertEqual(again.defaultPageId, pageID)
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

    @MainActor
    func test_onHabitChanged_firesOnCreate() throws {
        let ctx = container.mainContext
        let repo = HabitRepository(context: ctx)
        var events: [HabitChange] = []
        repo.onHabitChanged = { _, change in events.append(change) }

        let page = try repo.createPage(name: "P", emoji: "🅿", accentHex: "#2BFF5F")
        let habit = try repo.createHabit(name: "H", emoji: "💧", accentHex: "#3DA4FF",
                                         type: .manualOnce, targetReps: 1,
                                         weekdayMask: 0b01111111, on: page)
        try repo.updateHabit(habit, name: "H2")
        try repo.archiveHabit(habit)
        try repo.deleteHabit(habit)

        XCTAssertEqual(events, [.created, .updated, .archived, .deleted])
    }
}
