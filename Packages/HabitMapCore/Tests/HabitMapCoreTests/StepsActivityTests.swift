import XCTest
@testable import HabitMapCore

#if os(iOS)
import ActivityKit

final class StepsActivityTests: XCTestCase {
    func test_fraction_clampsAndGuardsZeroGoal() {
        XCTAssertEqual(StepsActivityAttributes.ContentState(current: 5_000, goal: 10_000).fraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(StepsActivityAttributes.ContentState(current: 20_000, goal: 10_000).fraction, 1.0)
        XCTAssertEqual(StepsActivityAttributes.ContentState(current: 3, goal: 0).fraction, 0.0)
    }

    func test_isComplete() {
        XCTAssertTrue(StepsActivityAttributes.ContentState(current: 10_000, goal: 10_000).isComplete)
        XCTAssertFalse(StepsActivityAttributes.ContentState(current: 9_999, goal: 10_000).isComplete)
        XCTAssertFalse(StepsActivityAttributes.ContentState(current: 1, goal: 0).isComplete)
    }

    func test_contentState_codableRoundTrip() throws {
        let state = StepsActivityAttributes.ContentState(current: 7_500, goal: 10_000)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(StepsActivityAttributes.ContentState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func test_attributes_storeName() {
        let attributes = StepsActivityAttributes(habitName: "Walk", accentHex: "#2BFF5F")
        XCTAssertEqual(attributes.habitName, "Walk")
        XCTAssertEqual(attributes.accentHex, "#2BFF5F")
    }
}
#endif
