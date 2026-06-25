import XCTest
@testable import HabitMapCore

final class RuleBasedCoachTests: XCTestCase {
    var coach: RuleBasedCoach!

    override func setUp() async throws {
        coach = RuleBasedCoach()
    }

    func test_learningFeatures_returnsLearningInsight() async throws {
        let f = SlipFeatures.empty
        let insight = try await coach.coach(features: f)
        XCTAssertEqual(insight.headline, CoachInsight.learning.headline)
    }

    func test_slipWindowDominates_picksSlipHeadline() async throws {
        var f = SlipFeatures.empty
        f = SlipFeatures(
            windowDays: 30, totalScheduled: 30, totalCompleted: 18,
            consistencyPct: 0.6,
            perHabit: [], weekdayCompletion: Array(repeating: 0.6, count: 7),
            topSlipWindows: [SlipWindow(weekday: 5, bucketHour: 18, skipRate: 0.75, attempts: 6)],
            idleHabits: [], strongPairs: [], recoveryDaysAverage: 1.2,
            streakBreakSignals: []
        )
        let insight = try await coach.coach(features: f)
        XCTAssertTrue(insight.headline.lowercased().contains("saturday"),
                      "Got: \(insight.headline)")
    }

    func test_idleHabit_picksIdleHeadline() async throws {
        let f = SlipFeatures(
            windowDays: 30, totalScheduled: 30, totalCompleted: 18,
            consistencyPct: 0.6,
            perHabit: [HabitFeatures(id: UUID(), name: "DRINK WATER", typeRaw: "manualOnce",
                                     consistency30d: 0.2, bestWeekday: nil, worstWeekday: nil,
                                     daysSinceLastLog: 10)],
            weekdayCompletion: Array(repeating: 0.6, count: 7),
            topSlipWindows: [],
            idleHabits: ["DRINK WATER"],
            strongPairs: [], recoveryDaysAverage: 0, streakBreakSignals: []
        )
        let insight = try await coach.coach(features: f)
        XCTAssertTrue(insight.headline.contains("Drink Water") || insight.headline.contains("DRINK WATER"))
    }

    func test_stackingPair_picksStackingHeadline() async throws {
        let f = SlipFeatures(
            windowDays: 30, totalScheduled: 30, totalCompleted: 25,
            consistencyPct: 0.83,
            perHabit: [], weekdayCompletion: Array(repeating: 0.83, count: 7),
            topSlipWindows: [], idleHabits: [],
            strongPairs: [HabitPair(a: "READ", b: "STRETCH", coOccurrenceRate: 0.89)],
            recoveryDaysAverage: 0, streakBreakSignals: []
        )
        let insight = try await coach.coach(features: f)
        XCTAssertTrue(insight.headline.contains("Read") || insight.headline.contains("Stretch"))
    }

    func test_lowConsistency_picksEaseUpHeadline() async throws {
        let f = SlipFeatures(
            windowDays: 30, totalScheduled: 30, totalCompleted: 9,
            consistencyPct: 0.3,
            perHabit: [], weekdayCompletion: Array(repeating: 0.3, count: 7),
            topSlipWindows: [], idleHabits: [], strongPairs: [],
            recoveryDaysAverage: 0, streakBreakSignals: []
        )
        let insight = try await coach.coach(features: f)
        XCTAssertEqual(insight.headline, "Ease up signal")
    }

    func test_gentleCopy_neverContainsBannedPhrase() async throws {
        let f = SlipFeatures(
            windowDays: 30, totalScheduled: 30, totalCompleted: 18,
            consistencyPct: 0.6,
            perHabit: [], weekdayCompletion: Array(repeating: 0.6, count: 7),
            topSlipWindows: [SlipWindow(weekday: 5, bucketHour: 18, skipRate: 0.75, attempts: 6)],
            idleHabits: [], strongPairs: [], recoveryDaysAverage: 0,
            streakBreakSignals: []
        )
        let insight = try await coach.coach(features: f)
        for phrase in NotificationCopy.bannedInGentle {
            XCTAssertFalse(insight.paragraph.lowercased().contains(phrase.lowercased()),
                           "Paragraph contains banned phrase '\(phrase)': \(insight.paragraph)")
            if let s = insight.suggestion {
                XCTAssertFalse(s.lowercased().contains(phrase.lowercased()),
                               "Suggestion contains banned phrase '\(phrase)': \(s)")
            }
        }
    }

    // A weekday that was scheduled but completed 0% of the time is exactly the WORST
    // day — it must be eligible. Before the fix the `> 0` filter dropped it, so the
    // coach saw no asymmetry and fell through to the generic "Steady rhythm" copy.
    func test_worstWeekday_includesGenuineZeroPercentDay() async throws {
        var completion = Array(repeating: 0.9, count: 7)
        completion[4] = 0.0 // Friday: scheduled but never completed
        let f = SlipFeatures(
            windowDays: 30, totalScheduled: 28, totalCompleted: 24,
            consistencyPct: 0.85,
            perHabit: [], weekdayCompletion: completion,
            weekdayAttempts: Array(repeating: 4, count: 7), // every weekday had attempts
            topSlipWindows: [], idleHabits: [], strongPairs: [],
            recoveryDaysAverage: 0, streakBreakSignals: []
        )
        let insight = try await coach.coach(features: f)
        XCTAssertNotEqual(insight.headline, "Steady rhythm",
                          "0% Friday should drive a weekday-strength insight, not fall through")
        XCTAssertTrue(insight.paragraph.contains("Fridays come in at 0%"),
                      "Worst (0%) day not surfaced: \(insight.paragraph)")
    }
}
