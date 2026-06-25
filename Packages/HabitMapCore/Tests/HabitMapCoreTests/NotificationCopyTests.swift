import XCTest
@testable import HabitMapCore

final class NotificationCopyTests: XCTestCase {
    func test_dailyReminder_gentleHasNoBannedPhrase() {
        assertNoBannedPhrase(NotificationCopy.dailyReminderBody(tone: .gentle))
    }

    func test_dailyReminder_bothTonesNonEmpty() {
        XCTAssertFalse(NotificationCopy.dailyReminderBody(tone: .gentle).isEmpty)
        XCTAssertFalse(NotificationCopy.dailyReminderBody(tone: .direct).isEmpty)
    }

    /// A repeating daily notification can't know the live remaining count, so the
    /// copy must not bake a (stale) number into the body.
    func test_dailyReminder_hasNoBakedCount() {
        for tone in [NotificationTone.gentle, .direct] {
            let body = NotificationCopy.dailyReminderBody(tone: tone)
            XCTAssertFalse(body.contains(where: \.isNumber),
                           "Daily reminder must not bake a stale count: \(body)")
        }
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
