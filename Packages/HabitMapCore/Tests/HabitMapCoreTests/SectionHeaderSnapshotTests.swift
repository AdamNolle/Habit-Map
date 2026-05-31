import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class SectionHeaderSnapshotTests: SnapshotTestCase {
    func test_titleOnly() {
        snap(SectionHeader("By page"))
    }

    func test_withAction() {
        snap(SectionHeader("Calendar", action: "36 weeks"))
    }

    func test_longTitle() {
        snap(SectionHeader("Risk windows", action: "7D × 8H"))
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
