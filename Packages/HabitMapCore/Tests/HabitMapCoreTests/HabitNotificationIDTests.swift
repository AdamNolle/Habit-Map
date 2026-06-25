import XCTest
import SwiftData
@testable import HabitMapCore

final class HabitNotificationIDTests: XCTestCase {
    func test_identifierRoundTrips() {
        let id = UUID()
        let identifier = HabitNotificationID.identifier(for: id)
        XCTAssertTrue(identifier.hasPrefix("habitmap.habit."))
        XCTAssertEqual(HabitNotificationID.parse(identifier), id)
    }

    func test_parse_rejectsForeignIdentifiers() {
        XCTAssertNil(HabitNotificationID.parse("habitmap.daily-reminder"))
        XCTAssertNil(HabitNotificationID.parse("habitmap.weekly-reflection"))
        XCTAssertNil(HabitNotificationID.parse(""))
    }

    func test_parse_rejectsMalformedUUID() {
        XCTAssertNil(HabitNotificationID.parse("habitmap.habit.not-a-uuid"))
    }

    func test_weekdayIdentifier_parsesBackToHabitID() {
        let id = UUID()
        let wdID = HabitNotificationID.identifier(for: id, weekday: 4)
        XCTAssertEqual(wdID, "habitmap.habit.\(id.uuidString).wd4")
        // A per-weekday identifier still routes a tap to the right habit.
        XCTAssertEqual(HabitNotificationID.parse(wdID), id)
    }

    func test_allIdentifiers_coverBaseAndEveryWeekday() {
        let id = UUID()
        let all = HabitNotificationID.allIdentifiers(for: id)
        XCTAssertEqual(all.count, 8) // base + 7 weekdays
        XCTAssertTrue(all.contains(HabitNotificationID.identifier(for: id)))
        for wd in 1...7 {
            XCTAssertTrue(all.contains(HabitNotificationID.identifier(for: id, weekday: wd)))
        }
        for identifier in all {
            XCTAssertEqual(HabitNotificationID.parse(identifier), id)
        }
    }

    @MainActor
    func test_pageID_findsPageContainingHabit() throws {
        let container = try ModelContainer(
            for: HabitPage.self, Habit.self, HabitCompletion.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let pageA = HabitPage(name: "A", emoji: "a", accentHex: "#FFFFFF", sortOrder: 0)
        let pageB = HabitPage(name: "B", emoji: "b", accentHex: "#FFFFFF", sortOrder: 1)
        let habit = Habit(name: "H", emoji: "h", accentHex: "#FFFFFF", type: .manualOnce, targetReps: 1, page: pageB)
        ctx.insert(pageA); ctx.insert(pageB); ctx.insert(habit)
        try ctx.save()

        XCTAssertEqual(HabitNotificationID.pageID(forHabit: habit.id, in: [pageA, pageB]), pageB.id)
        XCTAssertNil(HabitNotificationID.pageID(forHabit: UUID(), in: [pageA, pageB]))
    }
}
