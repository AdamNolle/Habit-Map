import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class SparklineSnapshotTests: XCTestCase {
    private let accent = Color(hex: "#2BFF5F")
    private let rising: [Double] = [0.1, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0]
    private let volatile: [Double] = [1.0, 0.0, 1.0, 0.0, 1.0, 0.5, 0.8, 0.2, 0.9, 0.4]
    private let flat: [Double] = Array(repeating: 0.75, count: 10)

    func test_rising() {
        snap(Sparkline(data: rising, accent: accent))
    }

    func test_volatile() {
        snap(Sparkline(data: volatile, accent: accent))
    }

    func test_flat() {
        snap(Sparkline(data: flat, accent: accent))
    }
}

private func snap(_ view: some View, file: StaticString = #file,
                  testName: String = #function, line: UInt = #line) {
    let wrapped = view
        .frame(width: 60, height: 24)
        .padding(8)
        .background(Color.black)
    assertSnapshot(of: wrapped, as: .image(precision: 0.99), file: file, testName: testName, line: line)
}
