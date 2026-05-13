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

    func test_habitReminder_gentleHasNoBannedPhrase() {
        let body = NotificationCopy.habitReminderBody(tone: .gentle, habitName: "Drink Water")
        assertNoBannedPhrase(body)
    }

    func test_habitReminder_directIsUppercase() {
        let title = NotificationCopy.habitReminderTitle(tone: .direct, habitName: "Drink Water")
        XCTAssertEqual(title, "DRINK WATER")
    }

    func test_habitReminder_gentleIsCapitalized() {
        let title = NotificationCopy.habitReminderTitle(tone: .gentle, habitName: "drink water")
        XCTAssertEqual(title, "Drink Water")
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
