import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class LavaBackgroundSnapshotTests: SnapshotTestCase {
    /// `isPaused` renders the deterministic t=0 frame (no TimelineView), which is
    /// the only stable way to snapshot an otherwise-animated view.
    func test_lavaBackground_pausedStaticFrame() {
        let view = LavaBackground(accent: Color(hex: "#2BFF5F"),
                                  secondary: Color(hex: "#B57BFF"),
                                  isPaused: true)
            .frame(width: 240, height: 360)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
