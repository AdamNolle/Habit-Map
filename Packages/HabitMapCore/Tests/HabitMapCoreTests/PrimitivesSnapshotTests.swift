import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class PrimitivesSnapshotTests: SnapshotTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_pip() {
        let view = Pip(color: accent, size: 10)
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_pageMark() {
        let view = PageMark(accent: accent, size: 18)
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_pageDots() {
        let view = PageDots(count: 4, activeIndex: 1, activeColor: accent)
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_dashRule() {
        let view = DashRule(accent: accent)
            .frame(width: 240)
            .padding(16).background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
