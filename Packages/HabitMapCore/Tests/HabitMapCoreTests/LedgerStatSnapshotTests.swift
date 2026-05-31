import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class LedgerStatSnapshotTests: SnapshotTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_withoutPip() {
        snap(LedgerStat(label: "This month", value: "87%", accent: accent))
    }

    func test_withPip() {
        snap(LedgerStat(label: "Streak", value: "14D", accent: accent, showPip: true))
    }

    func test_muted() {
        snap(LedgerStat(label: "Best", value: "21D", accent: DesignTokens.Surface.fg()))
    }
}

private func snap(_ view: some View, file: StaticString = #file,
                  testName: String = #function, line: UInt = #line) {
    let wrapped = view
        .frame(width: 120)
        .padding(16)
        .background(Color.black)
        .fixedSize()
    assertSnapshot(of: wrapped, as: .image(precision: 0.99), file: file, testName: testName, line: line)
}
