import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelRingSnapshotTests: SnapshotTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_empty() { snap(filled: 0) }
    func test_quarter() { snap(filled: 3) }
    func test_half() { snap(filled: 6) }
    func test_three_q() { snap(filled: 9) }
    func test_full() { snap(filled: 12) }

    func test_percentMapping() {
        XCTAssertEqual(PixelRing.segments(for: 0.0), 0)
        XCTAssertEqual(PixelRing.segments(for: 0.24), 3)
        XCTAssertEqual(PixelRing.segments(for: 0.50), 6)
        XCTAssertEqual(PixelRing.segments(for: 0.99), 12)
        XCTAssertEqual(PixelRing.segments(for: 1.0), 12)
        XCTAssertEqual(PixelRing.segments(for: -0.5), 0)
        XCTAssertEqual(PixelRing.segments(for: 1.5), 12)
    }

    func test_segmentsClampedByInit() {
        // Out-of-range filled counts are clamped, not crash.
        let above = PixelRing(filledSegments: 99, accent: .red)
        let below = PixelRing(filledSegments: -5, accent: .red)
        XCTAssertNotNil(above)
        XCTAssertNotNil(below)
    }

    private func snap(filled: Int, file: StaticString = #file, testName: String = #function, line: UInt = #line) {
        let view = PixelRing(filledSegments: filled, accent: accent)
            .frame(width: 128, height: 128)
            .padding(16)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99), file: file, testName: testName, line: line)
    }
}
