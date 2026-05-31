import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class StepsActivityViewSnapshotTests: SnapshotTestCase {
    func test_inProgress() {
        let view = StepsActivityView(habitName: "MORNING WALK", accentHex: "#2BFF5F",
                                     current: 6_200, goal: 10_000)
            .frame(width: 360, height: 76)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_complete() {
        let view = StepsActivityView(habitName: "MORNING WALK", accentHex: "#3DA4FF",
                                     current: 10_000, goal: 10_000)
            .frame(width: 360, height: 76)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
