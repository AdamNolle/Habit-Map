import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class EditorialLegendSnapshotTests: SnapshotTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_allDone() {
        snap(EditorialLegend(num: "01", level: .p100, accent: accent,
                             label: "All done", desc: "Every scheduled habit hit."))
    }

    func test_partial() {
        snap(EditorialLegend(num: "02", level: .p50, accent: accent,
                             label: "Partial", desc: "Some habits done."))
    }

    func test_rest() {
        snap(EditorialLegend(num: "03", level: .rest, accent: accent,
                             label: "Rest day", desc: "Nothing scheduled — guilt-free."))
    }

    func test_future() {
        snap(EditorialLegend(num: "04", level: .future, accent: accent,
                             label: "Future", desc: "Days yet to come."))
    }
}

private func snap(_ view: some View, file: StaticString = #file,
                  testName: String = #function, line: UInt = #line) {
    let wrapped = view
        .frame(width: 320)
        .padding(16)
        .background(Color.black)
        .fixedSize(horizontal: false, vertical: true)
    assertSnapshot(of: wrapped, as: .image(precision: 0.99), file: file, testName: testName, line: line)
}
