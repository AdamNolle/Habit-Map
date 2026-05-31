import XCTest
@testable import HabitMapCore

/// Bit-mask scheduling is the spine of every stats/forecast calculation, yet was
/// previously untested. Weekday index is `(Calendar.weekday + 5) % 7`, i.e.
/// Mon=0 … Sun=6. 2024-01-01 is a Monday, which anchors these fixtures.
final class HabitScheduleTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 12
        return Calendar.current.date(from: comps)!
    }

    private func habit(weekdayMask: Int8, restDayMask: Int8 = 0) -> Habit {
        Habit(name: "H", emoji: "x", accentHex: "#FFFFFF", type: .manualOnce,
              targetReps: 1, weekdayMask: weekdayMask, restDayMask: restDayMask)
    }

    // 2024-01-01 = Mon, 01-02 = Tue, … 01-07 = Sun
    private var monday: Date { date(2024, 1, 1) }
    private var wednesday: Date { date(2024, 1, 3) }
    private var sunday: Date { date(2024, 1, 7) }

    func test_mondayOnlyMask_scheduledOnlyMonday() {
        let h = habit(weekdayMask: 0b0000001) // bit 0 = Monday
        XCTAssertTrue(h.isScheduled(monday))
        XCTAssertFalse(h.isScheduled(wednesday))
        XCTAssertFalse(h.isScheduled(sunday))
    }

    func test_sundayBit_scheduledOnlySunday() {
        let h = habit(weekdayMask: 0b1000000) // bit 6 = Sunday
        XCTAssertTrue(h.isScheduled(sunday))
        XCTAssertFalse(h.isScheduled(monday))
    }

    func test_allDaysMask_scheduledEveryDay() {
        let h = habit(weekdayMask: 0b1111111)
        for offset in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: monday)!
            XCTAssertTrue(h.isScheduled(day), "offset \(offset) should be scheduled")
        }
    }

    func test_emptyMask_neverScheduled() {
        let h = habit(weekdayMask: 0)
        XCTAssertFalse(h.isScheduled(monday))
        XCTAssertFalse(h.isScheduled(sunday))
    }

    func test_restDayOverridesSchedule() {
        let h = habit(weekdayMask: 0b1111111, restDayMask: 0b0000001) // rest on Monday
        XCTAssertTrue(h.isRestDay(monday))
        XCTAssertFalse(h.isScheduled(monday), "a rest day is never scheduled")
        XCTAssertFalse(h.isRestDay(wednesday))
        XCTAssertTrue(h.isScheduled(wednesday))
    }

    func test_restDayMaskIndependentOfScheduleMask() {
        // Rest bit set for a weekday that isn't in the schedule mask anyway.
        let h = habit(weekdayMask: 0b0000001, restDayMask: 0b1000000)
        XCTAssertTrue(h.isRestDay(sunday))
        XCTAssertFalse(h.isRestDay(monday))
    }
}
