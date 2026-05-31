import XCTest
@testable import HabitMapCore

/// `isLearning` gates how hard the coach speaks. The boundary (3 completions)
/// is the difference between "we don't have enough signal yet" and real takes.
final class SlipFeaturesTests: XCTestCase {
    private func features(totalCompleted: Int) -> SlipFeatures {
        SlipFeatures(
            windowDays: 30, totalScheduled: 30, totalCompleted: totalCompleted,
            consistencyPct: 0.5, perHabit: [], weekdayCompletion: Array(repeating: 0, count: 7),
            topSlipWindows: [], idleHabits: [], strongPairs: [],
            recoveryDaysAverage: 0, streakBreakSignals: []
        )
    }

    func test_isLearning_belowThreshold() {
        XCTAssertTrue(features(totalCompleted: 0).isLearning)
        XCTAssertTrue(features(totalCompleted: 2).isLearning)
    }

    func test_isLearning_atThreshold_isNotLearning() {
        XCTAssertFalse(features(totalCompleted: 3).isLearning)
    }

    func test_isLearning_aboveThreshold() {
        XCTAssertFalse(features(totalCompleted: 25).isLearning)
    }

    func test_empty_isLearning() {
        XCTAssertTrue(SlipFeatures.empty.isLearning)
        XCTAssertEqual(SlipFeatures.empty.weekdayCompletion.count, 7)
    }

    func test_codableRoundTrip() throws {
        let original = features(totalCompleted: 7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SlipFeatures.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
