import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class InsightCardSnapshotTests: SnapshotTestCase {
    private func host<V: View>(_ view: V) -> some View {
        view.frame(width: 360).padding(16).background(Color.black).fixedSize()
    }

    func test_win() {
        let i = Insight(kind: .win, title: "STRONG MONDAYS",
                        body: "Drink Water hits 92% of Mondays — your best day.",
                        primaryAccentHex: "#2BFF5F")
        assertSnapshot(of: host(InsightCard(insight: i)), as: .image(precision: 0.99))
    }

    func test_risk() {
        let i = Insight(kind: .risk, title: "IDLE",
                        body: "Stretch — 10 days since last log.",
                        primaryAccentHex: "#FFB23D")
        assertSnapshot(of: host(InsightCard(insight: i)), as: .image(precision: 0.99))
    }

    func test_suggest() {
        let i = Insight(kind: .suggest, title: "STACK",
                        body: "Drink Water and Stretch co-occur 84% of the time. Pair them in your routine.",
                        primaryAccentHex: "#3DA4FF")
        assertSnapshot(of: host(InsightCard(insight: i)), as: .image(precision: 0.99))
    }
}
