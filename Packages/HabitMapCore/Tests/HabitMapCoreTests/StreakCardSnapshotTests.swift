import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class StreakCardSnapshotTests: SnapshotTestCase {
    func test_default() {
        let view = StreakCard(consistency: 0.81, currentStreak: 12, bestStreak: 34,
                              accent: Color(hex: "#2BFF5F"))
            .frame(width: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_zeros() {
        let view = StreakCard(consistency: 0.0, currentStreak: 0, bestStreak: 0,
                              accent: Color(hex: "#3DA4FF"))
            .frame(width: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
