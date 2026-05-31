import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class MiniIconSnapshotTests: SnapshotTestCase {
    func test_bell() {
        snap(MiniIcon("bell.fill", color: DesignTokens.Semantic.warn))
    }

    func test_heart() {
        snap(MiniIcon("heart.fill", color: DesignTokens.Semantic.delight))
    }

    func test_cloud() {
        snap(MiniIcon("cloud.fill", color: DesignTokens.Semantic.info))
    }

    func test_waveform() {
        snap(MiniIcon("waveform", color: DesignTokens.Semantic.ai))
    }
}

private func snap(_ view: some View, file: StaticString = #file,
                  testName: String = #function, line: UInt = #line) {
    let wrapped = view
        .padding(8)
        .background(Color.black)
        .fixedSize()
    assertSnapshot(of: wrapped, as: .image(precision: 0.99), file: file, testName: testName, line: line)
}
