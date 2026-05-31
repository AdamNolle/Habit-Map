import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class EditorialInsightSnapshotTests: SnapshotTestCase {
    private func render(_ insight: Insight, index: Int) -> some View {
        EditorialInsight(insight: insight, index: index)
            .frame(width: 340)
            .padding(16)
            .background(Color.black)
    }

    func test_win() {
        let insight = Insight(kind: .win, title: "STRONG MONDAYS",
                              body: "Run hits 92% of Mondays — your best day.",
                              primaryAccentHex: "#2BFF5F")
        assertSnapshot(of: render(insight, index: 0), as: .image(precision: 0.99))
    }

    func test_risk() {
        let insight = Insight(kind: .risk, title: "IDLE",
                              body: "Stretch — 9 days since last log. Want to pause it?",
                              primaryAccentHex: "#FFB23D")
        assertSnapshot(of: render(insight, index: 1), as: .image(precision: 0.99))
    }

    func test_suggest() {
        let insight = Insight(kind: .suggest, title: "STACK",
                              body: "Water and Vitamins co-occur 80% of the time. Pair them.",
                              primaryAccentHex: "#3DA4FF")
        assertSnapshot(of: render(insight, index: 2), as: .image(precision: 0.99))
    }
}
